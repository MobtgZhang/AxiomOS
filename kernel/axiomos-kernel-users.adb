with AxiomOS.Architecture;
with AxiomOS.Drivers.Virtio_Block;
with AxiomOS.Boot.ELF;
with AxiomOS.HAL.MMU;
with AxiomOS.HAL.Context;
with AxiomOS.HAL.CPU;
with AxiomOS.HAL.Console;
with AxiomOS.Kernel.State;
with AxiomOS.Process.Table;
with AxiomOS.Security.User_Memory;
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
   Text_Start : aliased U8 with Import, External_Name => "__text_start";
   Text_End : aliased U8 with Import, External_Name => "__text_end";
   RO_Start : aliased U8 with Import, External_Name => "__ro_start";
   RO_End : aliased U8 with Import, External_Name => "__ro_end";
   Data_Start : aliased U8 with Import, External_Name => "__data_start";
   Data_End : aliased U8 with Import, External_Name => "__data_end";

   procedure Copy_In (Caller : Process.Process_Record; Address : U64;
                       Buffer : out Bytes; Result : out Status) is
      P : U64;
   begin
      Security.User_Memory.Translate (Caller.Space, Address, U64 (Buffer'Length), False, P, Result);
      if Result = Success then Raw.Copy (Raw.Number (Buffer'Address), P, U64 (Buffer'Length)); end if;
   end Copy_In;
   procedure Copy_Out (Caller : Process.Process_Record; Address : U64;
                        Buffer : Bytes; Result : out Status) is
      P : U64;
   begin
      Security.User_Memory.Translate (Caller.Space, Address, U64 (Buffer'Length), True, P, Result);
      if Result = Success then Raw.Copy (P, Raw.Number (Buffer'Address), U64 (Buffer'Length)); end if;
   end Copy_Out;
   package Dispatcher is new Syscall.Dispatch (Copy_In, Copy_Out);

   function Dispatch (Number, A0, A1, A2 : U64) return U64
     with Export, Convention => C, External_Name => "axiom_user_dispatch";
   function Dispatch (Number, A0, A1, A2 : U64) return U64 is
      Reply : Syscall.Return_Value;
   begin
      Dispatcher.Invoke (Processes, Current, State.Files, Number,
                          (A0, A1, A2, others => 0), Reply);
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
      Process.Table.Exit_Process (Processes, Current, 128, S);
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

   procedure Execute (Info : Boot.Protocol.Boot_Info; Path : String;
                       Expect_Fault : Boolean; Result : out Status) is
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
            Process.Table.Exit_Process (Processes, Current, 127, S);
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
      Faulted := False;
      HAL.MMU.Activate (Root);
      Value := HAL.Context.Enter_User (Plan.Entry_Point, 16#805000#);
      Cleanup;
      Process.Table.Wait (Processes, Process.Kernel_PID, Current, Code, Result);
      Current := Process.Kernel_PID;
      if Result = Success and then
        (Faulted /= Expect_Fault or else (not Expect_Fault and then Value /= 0) or else
         (Expect_Fault and then Code /= 128))
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
      Memory.Physical.Allocate (State.Pages, 8, Page_Size, Memory.Physical.Kernel, Stack, Result);
      if Result /= Success then return; end if;
      HAL.Context.Initialize (Stack + 8 * Page_Size, Result);
      if Result /= Success then return; end if;
      HAL.MMU.Activate (Kernel_Root);
      HAL.Console.Line ("AXIOM:MMU:HARDWARE:PASS");
      VFS.Tmpfs.Create (State.Files, "/dev", VFS.Directory, Node, Result);
      if Result /= Success then return; end if;
      VFS.Tmpfs.Create (State.Files, "/dev/console", VFS.Character_Device, Node, Result);
      if Result /= Success then return; end if;
      Execute (Info, "/bin/init", False, Result);
      if Result /= Success then return; end if;
      HAL.Console.Line ("AXIOM:USER:SYSCALL:PASS");
      Execute (Info, "/bin/isolation-probe", True, Result);
      if Result /= Success then return; end if;
      HAL.Console.Line ("AXIOM:USER:ISOLATION:PASS");
      HAL.Console.Line ("AXIOM:USER:RECLAIM:PASS");
   end Run;
end AxiomOS.Kernel.Users;
