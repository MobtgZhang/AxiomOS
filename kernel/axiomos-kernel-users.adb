with AxiomOS.Architecture;
with AxiomOS.Drivers.Virtio_Block;
with AxiomOS.Boot.ELF;
with AxiomOS.HAL.MMU;
with AxiomOS.HAL.Context;
with AxiomOS.HAL.CPU;
with AxiomOS.HAL.Console;
with AxiomOS.Kernel.State;
with AxiomOS.Process.Table;
with AxiomOS.Security.Copies;
with AxiomOS.Memory.Spaces;
with AxiomOS.HAL.Clock;
with AxiomOS.Syscall.Dispatch;
with AxiomOS.IO.Handles;
with AxiomOS.Memory.Virtual;
with AxiomOS.Memory.Physical;
with AxiomOS.VFS.Tmpfs;
with AxiomOS.VFS.Mounts;
with AxiomOS.Raw;
package body AxiomOS.Kernel.Users is
   use type U64, U32, Process.PID;
   type U64_Array is array (Natural range <>) of U64;
   Processes : Process.Manager;
   Current : Process.PID;
   Kernel_Root : U64;
   Faulted : Boolean;
   Fault_Address : U64;
   Text_Start : aliased U8 with Import, External_Name => "__text_start";
   Text_End : aliased U8 with Import, External_Name => "__text_end";
   RO_Start : aliased U8 with Import, External_Name => "__ro_start";
   RO_End : aliased U8 with Import, External_Name => "__ro_end";
   Data_Start : aliased U8 with Import, External_Name => "__data_start";
   Data_End : aliased U8 with Import, External_Name => "__data_end";

   package User_Copy is new Security.Copies (Raw.Copy, Raw.Number);
   procedure Copy_In (Caller : Process.Process_Record; Address : U64;
                       Buffer : out Bytes; Result : out Status) is
   begin User_Copy.Read (Caller.Space, Address, Buffer, Result); end Copy_In;
   procedure Copy_Out (Caller : Process.Process_Record; Address : U64;
                        Buffer : Bytes; Result : out Status) is
   begin User_Copy.Write (Caller.Space, Address, Buffer, Result); end Copy_Out;
   package Dispatcher is new Syscall.Dispatch (Copy_In, Copy_Out);

   function Dispatch (Number, A0, A1, A2 : U64) return U64
     with Export, Convention => C, External_Name => "axiom_user_dispatch";
   function Dispatch (Number, A0, A1, A2 : U64) return U64 is
      Reply : Syscall.Return_Value;
      Index : constant Natural := Process.Table.Resolve (Processes, Current);
      Rights : Memory.Virtual.Permissions;
   begin
      Reply := (0, Invalid_Argument);
      if Index = 0 then return 0 - U64 (Status'Pos (Bad_Handle) + 1); end if;
      case Number is
         when 7 | 13 =>
            if A2 > 7 or else (A2 and 1) = 0 then return 0 - U64 (Status'Pos (Invalid_Argument) + 1); end if;
            Rights := (True, (A2 and 2) /= 0, (A2 and 4) /= 0, True, False);
            if Number = 7 then
               Memory.Spaces.Allocate (State.Pages, Processes.Entries (Index).Space,
                 Processes.Entries (Index).Hardware_Root, A0, A1, Rights, Reply.Error);
               Reply.Value := A0;
            else
               Memory.Spaces.Protect (State.Pages, Processes.Entries (Index).Space,
                 Processes.Entries (Index).Hardware_Root, A0, A1, Rights, Reply.Error);
            end if;
         when 8 =>
            Memory.Spaces.Release (State.Pages, Processes.Entries (Index).Space,
              Processes.Entries (Index).Hardware_Root, A0, A1, Reply.Error);
         when 11 => Reply := (HAL.Clock.Now, Success);
         when others =>
            Dispatcher.Invoke (Processes, Current, State.Files, Number,
                                (A0, A1, A2, others => 0), Reply);
      end case;
      if Reply.Error /= Success then return 0 - U64 (Status'Pos (Reply.Error) + 1); end if;
      if Number = 0 then HAL.Context.Leave_User (A0); end if;
      return Reply.Value;
   end Dispatch;
   procedure User_Fault (Address, Cause : U64)
     with Export, Convention => C, External_Name => "axiom_user_fault", No_Return;
   procedure User_Fault (Address, Cause : U64) is
      S : Status;
   begin
      HAL.Console.Put ("AXIOM:USER:FAULT address="); HAL.Console.Hex (Address);
      HAL.Console.Put (" cause="); HAL.Console.Hex (Cause); HAL.Console.Line ("");
      Faulted := True;
      Fault_Address := Address;
      Process.Table.Exit_Process (Processes, Current, State.Files, 128, S);
      HAL.Context.Leave_User (128);
   end User_Fault;
   procedure Kernel_Fault with Export, Convention => C,
     External_Name => "axiom_kernel_fault", No_Return;
   procedure Kernel_Fault is
   begin HAL.Console.Panic ("unhandled kernel exception"); end Kernel_Fault;

   procedure Protect_Kernel (Root : U64; Result : out Status) is
      procedure Region (First, Last : U64; W, X : Boolean) is
         P : U64 := First;
      begin
         while P < Last loop
            HAL.MMU.Map_Page (State.Pages, Root, P, P,
              (True, W, X, False, False), Result);
            exit when Result /= Success;
            P := P + Page_Size;
         end loop;
      end Region;
   begin
      Region (Raw.Number (Text_Start'Address), Raw.Number (Text_End'Address), False, True);
      if Result /= Success then return; end if;
      Region (Raw.Number (RO_Start'Address), Raw.Number (RO_End'Address), False, False);
      if Result /= Success then return; end if;
      Region (Raw.Number (Data_Start'Address), Raw.Number (Data_End'Address), True, False);
      if Result /= Success then return; end if;
      for Address of U64_Array'(Drivers.Virtio_Block.Common_Address,
                                Drivers.Virtio_Block.Notify_Address) loop
         HAL.MMU.Map_Page (State.Pages, Root, Address / Page_Size * Page_Size,
           Address / Page_Size * Page_Size, (True, True, False, False, True), Result);
         if Result /= Success then return; end if;
      end loop;
   end Protect_Kernel;

   procedure Check_Leaf_Rollback is
      Arena : Memory.Physical.Allocator;
      Backing, PA : U64;
      Rights : Memory.Virtual.Permissions;
      S : Status;
      Base : constant U64 := Memory.Spaces.User_First;
   begin
      Memory.Physical.Allocate (State.Pages, 4, Page_Size, Memory.Physical.Kernel, Backing, S);
      if S /= Success then HAL.Console.Panic ("leaf test backing"); end if;
      -- All backends need two missing levels at this address. Exhaust at each
      -- level, then verify unmap prunes the partial path without losing pages.
      for Budget in 0 .. 2 loop
         Memory.Physical.Reset (Arena);
         if Budget > 0 then
            Memory.Physical.Add_Region (Arena, Backing, U64 (Budget) * Page_Size, S);
            if S /= Success then HAL.Console.Panic ("leaf test arena"); end if;
         end if;
         HAL.MMU.Map_Page (Arena, Kernel_Root, Base, Backing + 3 * Page_Size,
           (True, True, False, True, False), S);
         if (Budget < 2 and then S /= Out_Of_Memory) or else
           (Budget = 2 and then S /= Success) then HAL.Console.Panic ("leaf allocation budget"); end if;
         HAL.MMU.Query_Page (Kernel_Root, Base, PA, Rights, S);
         if (Budget < 2 and then S /= Not_Found) or else
           (Budget = 2 and then (S /= Success or else PA /= Backing + 3 * Page_Size or else not Rights.User)) then
            HAL.Console.Panic ("leaf query");
         end if;
         HAL.MMU.Unmap_Page (Arena, Kernel_Root, Base, S);
         HAL.MMU.Activate (Kernel_Root);
         if Arena.Available /= Budget then HAL.Console.Panic ("leaf rollback pages"); end if;
         HAL.MMU.Query_Page (Kernel_Root, Base, PA, Rights, S);
         if S /= Not_Found then HAL.Console.Panic ("leaf unmap"); end if;
      end loop;
      Memory.Physical.Release (State.Pages, Backing, 4, S);
      if S /= Success then HAL.Console.Panic ("leaf test release"); end if;
      HAL.Console.Line ("AXIOM:MMU:LEAF:PASS");
   end Check_Leaf_Rollback;

   procedure Execute (Info : Boot.Protocol.Boot_Info; Path : String;
                       Expect_Fault : Boolean; Result : out Status;
                       Expected_Address : U64 := 0) is
      Node : VFS.Node_Id;
      Image : Bytes (0 .. VFS.Max_File_Size - 1);
      Image_Length : Natural;
      Plan : Boot.ELF.Layout;
      Root, Physical, Length, Value : U64;
      Slot : Natural;
      Code : U32;
      H : IO.Handle;
      S : Status;
      Available : constant Natural := State.Pages.Available;
      procedure Cleanup (Abort_Load : Boolean := False) is
      begin
         HAL.MMU.Activate (Kernel_Root);
         HAL.MMU.Destroy (State.Pages, Root);
         if Current /= Process.Kernel_PID then
            for M of Processes.Entries (Slot).Space.Entries loop
               if M.Active then
                  Memory.Physical.Release (State.Pages, M.Physical_Base,
                                            Positive (M.Length / Page_Size), S);
               end if;
            end loop;
         end if;
         if Abort_Load and then Current /= Process.Kernel_PID then
            Process.Table.Exit_Process (Processes, Current, State.Files, 127, S);
            Process.Table.Wait (Processes, Process.Kernel_PID, Current, Code, S);
            Current := Process.Kernel_PID;
         end if;
         if State.Pages.Available /= Available then
            HAL.Console.Panic ("process page reclamation");
         end if;
      end Cleanup;
      procedure Install (VA, PA, Size : U64; Rights : Memory.Virtual.Permissions) is
      begin
         Memory.Virtual.Map (Processes.Entries (Slot).Space, VA, PA, Size, Rights, Result);
         if Result /= Success then
            -- Ownership transfers to Space only after its mapping succeeds.
            Memory.Physical.Release (State.Pages, PA, Positive (Size / Page_Size), S);
            return;
         end if;
         for I in 0 .. Natural (Size / Page_Size) - 1 loop
            HAL.MMU.Map_Page (State.Pages, Root, VA + U64 (I) * Page_Size,
                              PA + U64 (I) * Page_Size, Rights, Result);
            if Result /= Success then return; end if;
         end loop;
      end Install;
   begin
      VFS.Mounts.Lookup (State.Files, Path, Node, Result);
      if Result /= Success then return; end if;
      VFS.Mounts.Read (State.Files, Node, 0, Image, Image_Length, Result);
      if Result /= Success then return; end if;
      if Image_Length = 0 or else U64 (Image_Length) /= U64 (State.Files.Nodes (Node).Length) then
         Result := Unsupported; return;
      end if;
      Boot.ELF.Validate (Image (0 .. Image_Length - 1),
                        Architecture.ELF_Machine, Plan, Result, Expected_Type => 2);
      if Result /= Success then return; end if;
      if Plan.Dynamic_Size /= 0 then Result := Unsupported; return; end if;
      for I in 1 .. Plan.Count loop
         if not Aligned (Plan.Segments (I).Virtual_Base, Page_Size) or else
           Plan.Segments (I).Virtual_Base < 16#400000# or else
           Plan.Segments (I).Virtual_Base + Plan.Segments (I).Memory_Size >= 16#800000#
         then Result := Corrupt; return; end if;
      end loop;
      HAL.MMU.Create (State.Pages, Info, Root, Result);
      if Result /= Success then return; end if;
      Protect_Kernel (Root, Result);
      if Result /= Success then HAL.MMU.Destroy (State.Pages, Root); return; end if;
      Process.Table.Create (Processes, Process.Kernel_PID, (1000, 1000), Current, Result);
      if Result /= Success then HAL.MMU.Destroy (State.Pages, Root); return; end if;
      Slot := Process.Table.Resolve (Processes, Current);
      Processes.Entries (Slot).Hardware_Root := Root;
      for I in 1 .. Plan.Count loop
         declare Seg : Boot.ELF.Segment renames Plan.Segments (I);
         begin
            Length := ((Seg.Memory_Size + Page_Size - 1) / Page_Size) * Page_Size;
            Memory.Physical.Allocate (State.Pages, Positive (Length / Page_Size),
                                      Page_Size, Memory.Physical.Process, Physical, Result);
            if Result /= Success then Cleanup (Abort_Load => True); return; end if;
            Raw.Zero (Physical, Length);
            Raw.Copy (Physical, Raw.Number (Image'Address) + Seg.Offset, Seg.File_Size);
            HAL.CPU.Sync_Code (Physical, Length);
            Install (Seg.Virtual_Base, Physical, Length,
                     (True, (Seg.Flags and 2) /= 0, (Seg.Flags and 1) /= 0, True, False));
            if Result /= Success then Cleanup (Abort_Load => True); return; end if;
         end;
      end loop;
      Memory.Physical.Allocate (State.Pages, 4, Page_Size, Memory.Physical.Process, Physical, Result);
      if Result /= Success then Cleanup (Abort_Load => True); return; end if;
      Raw.Zero (Physical, 4 * Page_Size);
      Install (16#801000#, Physical, 4 * Page_Size, (True, True, False, True, False));
      if Result /= Success then Cleanup (Abort_Load => True); return; end if;
      IO.Handles.Open (Processes.Entries (Slot).Handles, State.Files, "/dev/console",
                       (False, True), H, Result);
      if Result /= Success then Cleanup (Abort_Load => True); return; end if;
      Process.Table.Make_Ready (Processes, Current, Plan.Entry_Point, 16#805000#, Result);
      if Result /= Success then Cleanup (Abort_Load => True); return; end if;
      Process.Table.Start (Processes, Current, Result);
      if Result /= Success then Cleanup (Abort_Load => True); return; end if;
      Faulted := False; Fault_Address := 0;
      HAL.MMU.Activate (Root);
      Value := HAL.Context.Enter_User (Plan.Entry_Point, 16#805000#);
      Cleanup;
      Process.Table.Wait (Processes, Process.Kernel_PID, Current, Code, Result);
      Current := Process.Kernel_PID;
      if Result = Success and then
        (Faulted /= Expect_Fault or else (not Expect_Fault and then Value /= 0) or else
         (Expect_Fault and then (Code /= 128 or else Fault_Address /= Expected_Address)))
      then Result := Corrupt; end if;
   end Execute;

   procedure Run (Info : Boot.Protocol.Boot_Info; Result : out Status) is
      Node : VFS.Node_Id;
      Stack : U64;
   begin
      Process.Table.Initialize (Processes);
      Current := Process.Kernel_PID;
      HAL.MMU.Create (State.Pages, Info, Kernel_Root, Result);
      if Result /= Success then return; end if;
      Protect_Kernel (Kernel_Root, Result);
      if Result /= Success then return; end if;
      -- VFS cache initialization has a 32 KiB bounded node temporary, in
      -- addition to syscall and filesystem frames. Do not reuse the small AP
      -- stack size for this deeper synchronous call chain.
      Memory.Physical.Allocate (State.Pages, 64, Page_Size, Memory.Physical.Kernel, Stack, Result);
      if Result /= Success then return; end if;
      HAL.Context.Initialize (Stack + 64 * Page_Size, Result);
      if Result /= Success then return; end if;
      HAL.MMU.Activate (Kernel_Root);
      HAL.Console.Line ("AXIOM:MMU:HARDWARE:PASS");
      Check_Leaf_Rollback;
      VFS.Mounts.Mount_Tmpfs (State.Files, "/dev", Result);
      if Result /= Success then return; end if;
      VFS.Tmpfs.Create (State.Files, "/dev/console", VFS.Character_Device, Node, Result);
      if Result /= Success then return; end if;
      VFS.Tmpfs.Create (State.Files, "/tmp/user-data", VFS.Regular, Node, Result);
      if Result /= Success then return; end if;
      Execute (Info, "/bin/init", False, Result);
      if Result /= Success then return; end if;
      VFS.Mounts.Unmount (State.Files, "/tmp", Result);
      if Result /= Success then return; end if;
      HAL.Console.Line ("AXIOM:USER:HANDLES:PASS");
      HAL.Console.Line ("AXIOM:USER:SYSCALL:PASS");
      Execute (Info, "/bin/isolation-probe", True, Result, 16#100000#);
      if Result /= Success then return; end if;
      HAL.Console.Line ("AXIOM:USER:ISOLATION:PASS");
      Execute (Info, "/bin/memory-probe", True, Result, Memory.Spaces.User_First);
      if Result /= Success then return; end if;
      HAL.Console.Line ("AXIOM:USER:PROTECT:PASS");
      Execute (Info, "/bin/unmap-probe", True, Result, Memory.Spaces.User_First);
      if Result /= Success then return; end if;
      HAL.Console.Line ("AXIOM:USER:UNMAP:PASS");
      HAL.Console.Line ("AXIOM:USER:RECLAIM:PASS");
   end Run;
end AxiomOS.Kernel.Users;
