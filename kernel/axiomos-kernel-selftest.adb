with AxiomOS.Kernel.State;
with AxiomOS.Types; use AxiomOS.Types;
with AxiomOS.Memory.Physical;
with AxiomOS.Memory.Heap;
with AxiomOS.Memory.Virtual;
with AxiomOS.SMP.Topology;
with AxiomOS.SMP.Startup;
with AxiomOS.Scheduler.Run_Queues;
with AxiomOS.IO.Handles;
with AxiomOS.IO.Streams;
with AxiomOS.VFS.Tmpfs;
with AxiomOS.Drivers.Registry;
with AxiomOS.Drivers.Lifecycle;
with AxiomOS.Raw;
with AxiomOS.HAL.Console;
with AxiomOS.HAL.CPU;
with AxiomOS.HAL.MMU;
with AxiomOS.Kernel.Locks;
with AxiomOS.Jobs;
package body AxiomOS.Kernel.Selftest is
   use type U64, U32, U16, Memory.Physical.Owner;
   procedure Require (Condition : Boolean; Message : String) is
   begin if not Condition then HAL.Console.Panic (Message); end if; end Require;
   procedure Check_MMU_Rollback (Info : Boot.Protocol.Boot_Info) is
      Arena : Memory.Physical.Allocator;
      Backing, Root : U64;
      S : Status;
   begin
      Memory.Physical.Allocate (State.Pages, 4, Page_Size, Memory.Physical.Kernel, Backing, S);
      Require (S = Success, "MMU test backing");
      -- A real bounded arena forces failure at successive table allocations.
      -- No test changes the live allocator's free count or ownership metadata.
      for Budget in 0 .. 4 loop
         Memory.Physical.Reset (Arena);
         if Budget > 0 then
            Memory.Physical.Add_Region (Arena, Backing, U64 (Budget) * Page_Size, S);
            Require (S = Success, "MMU test arena");
         end if;
         HAL.MMU.Create (Arena, Info, Root, S);
         Require (S = Out_Of_Memory and Root = 0 and Arena.Available = Budget,
                  "MMU allocation rollback");
         for I in 0 .. Budget - 1 loop
            Require (Arena.Metadata (I).Kind = Memory.Physical.Free and
                     Arena.Metadata (I).References = 0, "MMU rollback ownership");
         end loop;
      end loop;
      Memory.Physical.Release (State.Pages, Backing, 4, S);
      Require (S = Success, "MMU test release");
      HAL.Console.Line ("AXIOM:MMU:ROLLBACK:PASS");
   end Check_MMU_Rollback;
   --  Map through every level of the page table: scattered 4 KiB mappings
   --  that force new upper-level tables and 2 MiB splits on every backend.
   procedure Check_Four_Level_Walk (Info : Boot.Protocol.Boot_Info) is
      Arena : Memory.Physical.Allocator;
      Region, Backing, Root, PA : U64;
      Rights : Memory.Virtual.Permissions;
      S : Status;
      Available : constant Natural := State.Pages.Available;
      --  LoongArch's Create eagerly builds the whole 4 GiB / 4 KiB identity
      --  map (about 2053 table pages); size the arena for the most expensive
      --  backend. Every page is reclaimed by Destroy below.
      Walk_Pages : constant := 2100;
      --  Four scattered 4 KiB mappings that force new PDPT/PD/PT
      --  allocations and 2 MiB splits on every backend. All addresses stay
      --  below the Sv39 2**38 limit so one source runs on all four ISAs;
      --  on x86-64 and AArch64 the walk still traverses all four levels.
      VA : constant array (1 .. 4) of U64 :=
        (16#0000_0000_0000_1000#, 16#0000_0000_2040_1000#,
         16#0000_0000_4080_1000#, 16#0000_0001_00BF_F000#);
   begin
      Memory.Physical.Allocate (State.Pages, Walk_Pages, Page_Size,
                                Memory.Physical.Kernel, Region, S);
      Require (S = Success, "level test region");
      Memory.Physical.Allocate (State.Pages, 4, Page_Size, Memory.Physical.Kernel,
                                Backing, S);
      Require (S = Success, "level test backing");
      Memory.Physical.Reset (Arena);
      Memory.Physical.Add_Region (Arena, Region, U64 (Walk_Pages) * Page_Size, S);
      Require (S = Success, "level test arena");
      HAL.MMU.Create (Arena, Info, Root, S);
      Require (S = Success and Root /= 0, "level test root");
      for I in VA'Range loop
         HAL.MMU.Map_Page (Arena, Root, VA (I), Backing + U64 (I - 1) * Page_Size,
                           (True, True, False, False, False), S);
         Require (S = Success, "level test map");
      end loop;
      for I in VA'Range loop
         HAL.MMU.Query_Page (Root, VA (I), PA, Rights, S);
         Require (S = Success and then PA = Backing + U64 (I - 1) * Page_Size and then
                    not Rights.User and then Rights.Writable and then
                    not Rights.Executable,
                  "level test query");
      end loop;
      HAL.MMU.Destroy (Arena, Root);
      Require (Arena.Available = Walk_Pages, "four level reclaim");
      Memory.Physical.Release (State.Pages, Backing, 4, S);
      Require (S = Success, "level test backing release");
      Memory.Physical.Release (State.Pages, Region, Walk_Pages, S);
      Require (S = Success and State.Pages.Available = Available, "level test release");
      HAL.Console.Line ("AXIOM:MMU:LEVELS:PASS");
   end Check_Four_Level_Walk;

   --  Ticket spinlock, ownership-checked mutex and bounded semaphore over
   --  the real architecture atomics (single-core sequential semantics).
   procedure Check_Sync is
      use AxiomOS.Kernel.Locks;
      Lock : Spinlock;
      Guard : Mutex;
      Sema : Semaphore;
      S : Status;
   begin
      Initialize (Lock);
      for I in 1 .. 2 loop
         Acquire (Lock);
         Release (Lock);
      end loop;
      Acquire (Guard, 1, S);
      Require (S = Success, "sync mutex acquire");
      Require (Try_Acquire (Guard, 2) = Would_Block, "sync mutex conflict");
      Require (Try_Acquire (Guard, 1) = Invalid_Argument, "sync mutex recursion");
      Release (Guard, 2, S);
      Require (S = Permission_Denied, "sync mutex foreign release");
      Release (Guard, 1, S);
      Require (S = Success, "sync mutex release");
      Initialize (Sema, 1, 3);
      Up (Sema, S); Require (S = Success, "sync sema up");
      Up (Sema, S); Require (S = Success, "sync sema up 2");
      Up (Sema, S); Require (S = No_Space, "sync sema maximum");
      Require (Try_Down (Sema) = Success, "sync sema down");
      Require (Try_Down (Sema) = Success, "sync sema down 2");
      Require (Try_Down (Sema) = Success, "sync sema down 3");
      Require (Try_Down (Sema) = Would_Block, "sync sema empty");
      HAL.Console.Line ("AXIOM:SYNC:PASS");
   end Check_Sync;

   --  Full job lifecycle on the kernel job table: priority admission under
   --  a page budget, failure collection and cancellation.
   procedure Check_Jobs is
      use AxiomOS.Jobs;
      Program : String (1 .. Max_Program);
      Program_Length : Natural;
      Pages : U64;
      High, Low : Job_Id;
      Code : U32;
      S : Status;
   begin
      Initialize (State.Job_Table);
      Set_Page_Limit (State.Job_Table, 9);
      Submit (State.Job_Table, "/bin/init", 3, Jobs.System, 1000, 1, Low, S);
      Require (S = Success, "job submit low");
      Submit (State.Job_Table, "/bin/other", 7, Jobs.Interactive, 1000, 9, High, S);
      Require (S = Success and High /= Low, "job submit high");
      Admit (State.Job_Table, Program, Program_Length, Pages, High, S);
      Require (S = Success and then Program (1 .. Program_Length) = "/bin/other" and then
                 Pages = 9 and then Reserved_Pages (State.Job_Table) = 9,
               "job priority admission");
      Admit (State.Job_Table, Program, Program_Length, Pages, Low, S);
      Require (S = Out_Of_Memory, "job page budget");
      Fail (State.Job_Table, High, S);
      Require (S = Success and Reserved_Pages (State.Job_Table) = 0, "job fail releases pages");
      Wait (State.Job_Table, High, Code, S);
      Require (S = Success and Code = 127, "job failure exit code");
      Wait (State.Job_Table, High, Code, S);
      Require (S = Bad_Handle, "job collection frees the slot");
      Admit (State.Job_Table, Program, Program_Length, Pages, Low, S);
      Require (S = Success and then Program (1 .. Program_Length) = "/bin/init" and then
                 Pages = 1 and then Reserved_Pages (State.Job_Table) = 1,
               "job admission after collection");
      Cancel (State.Job_Table, Low, S);
      Require (S = Success and Reserved_Pages (State.Job_Table) = 0, "job cancel releases pages");
      Wait (State.Job_Table, Low, Code, S);
      Require (S = Bad_Handle, "cancelled job id invalid");
      Require (Count (State.Job_Table, Empty) = Max_Jobs, "job table drained");
      HAL.Console.Line ("AXIOM:JOBS:PASS");
   end Check_Jobs;

   procedure Run (Info : Boot.Protocol.Boot_Info) is
      S : Status;
      A, B : U64;
      Heap : Memory.Heap.Allocator;
      Available : constant Natural := State.Pages.Available;
      VM : Memory.Virtual.Address_Space;
      H : IO.Handle;
      N : VFS.Node_Id;
      Count, Device, Driver : Natural;
      Buffer : Bytes (0 .. 63);
      CPU : SMP.CPU_Index;
      Thread : U32;
   begin
      Memory.Physical.Allocate (State.Pages, 2, 8192, Memory.Physical.Kernel, A, S);
      Require (S = Success and then A mod 8192 = 0, "PMM allocation");
      Raw.Store64 (A, 16#0123456789ABCDEF#);
      Raw.Store64 (A + 4096, 16#FEDCBA9876543210#);
      Require (Raw.Load64 (A) = 16#0123456789ABCDEF# and then
               Raw.Load64 (A + 4096) = 16#FEDCBA9876543210#, "physical memory readback");
      Memory.Physical.Release (State.Pages, A, 2, S);
      Require (S = Success and State.Pages.Available = Available, "PMM release");
      HAL.Console.Line ("AXIOM:PMM:PASS");
      Check_MMU_Rollback (Info);
      Check_Four_Level_Walk (Info);
      Memory.Heap.Initialize (Heap);
      Memory.Heap.Allocate (Heap, State.Pages, 40, 16, A, S);
      Require (S = Success, "heap small allocation");
      Raw.Store64 (A, 123);
      Memory.Heap.Allocate (Heap, State.Pages, 6000, 4096, B, S);
      Require (S = Success, "heap large allocation");
      Raw.Store64 (B + 4096, 456);
      Require (Raw.Load64 (A) = 123 and Raw.Load64 (B + 4096) = 456, "heap memory");
      Memory.Heap.Free (Heap, State.Pages, A, S); Require (S = Success, "heap free");
      Memory.Heap.Free (Heap, State.Pages, B, S);
      Require (S = Success and State.Pages.Available = Available, "heap reclaim");
      HAL.Console.Line ("AXIOM:HEAP:PASS");
      Memory.Virtual.Map (VM, 4096, A, 4096, (True, False, True, True, False), S);
      Require (S = Success and then Memory.Virtual.Check_User (VM, 4096, 16), "VM policy");
      Require (not Memory.Virtual.Check_User (VM, 4096, 16, True), "VM permission");
      HAL.Console.Line ("AXIOM:VM:POLICY:PASS");
      IO.Handles.Open (State.Handles, State.Files, "/etc/motd", (True, False), H, S);
      Require (S = Success, "initramfs motd");
      IO.Streams.Read (State.Handles, State.Files, H, Buffer, Count, S);
      Require (S = Success and Count > 0, "initramfs read");
      IO.Handles.Close (State.Handles, State.Files, H, S);
      VFS.Tmpfs.Create (State.Files, "/tmp", VFS.Directory, N, S);
      Require (S = Success, "tmpfs mkdir");
      VFS.Tmpfs.Create (State.Files, "/tmp/check", VFS.Regular, N, S);
      Require (S = Success, "tmpfs create");
      IO.Handles.Open (State.Handles, State.Files, "/tmp/check", (True, True), H, S);
      Require (S = Success, "tmpfs open");
      IO.Streams.Write (State.Handles, State.Files, H, (65, 100, 97), Count, S);
      Require (S = Success and Count = 3, "tmpfs write");
      IO.Handles.Close (State.Handles, State.Files, H, S);
      HAL.Console.Line ("AXIOM:VFS:PASS");
      HAL.Console.Line ("AXIOM:IO:PASS");
      SMP.Topology.Register_CPU (State.CPUs, 0, True, CPU, S);
      Require (S = Success, "BSP registration");
      Scheduler.Run_Queues.Enqueue (State.CPUs, CPU, 1, S);
      Require (S = Success, "run queue enqueue");
      Scheduler.Run_Queues.Dequeue (State.CPUs, CPU, Thread, S);
      Require (S = Success and Thread = 1, "run queue dequeue");
      HAL.Console.Line ("AXIOM:SMP:POLICY:PASS");
      Drivers.Registry.Register_Driver (State.Devices, Drivers.Serial, 0, 0, Driver, S);
      Require (S = Success, "serial driver register");
      Drivers.Registry.Discover (State.Devices,
        (Drivers.Discovered, Drivers.Serial, 0, 0, 0, 0, 0, 0), Device, S);
      Require (S = Success, "serial discover");
      Drivers.Registry.Bind (State.Devices, Device, S);
      Require (S = Success, "serial driver bind");
      Drivers.Lifecycle.Set_Running (State.Devices, Device, S);
      Require (S = Success, "serial driver start");
      HAL.Console.Line ("AXIOM:DRIVERS:PASS");
      Check_Sync;
      Check_Jobs;
   end Run;
end AxiomOS.Kernel.Selftest;
