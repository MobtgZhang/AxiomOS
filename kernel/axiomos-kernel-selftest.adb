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
with AxiomOS.HAL.MMU;
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
      IO.Handles.Close (State.Handles, H, S);
      VFS.Tmpfs.Create (State.Files, "/tmp", VFS.Directory, N, S);
      Require (S = Success, "tmpfs mkdir");
      VFS.Tmpfs.Create (State.Files, "/tmp/check", VFS.Regular, N, S);
      Require (S = Success, "tmpfs create");
      IO.Handles.Open (State.Handles, State.Files, "/tmp/check", (True, True), H, S);
      Require (S = Success, "tmpfs open");
      IO.Streams.Write (State.Handles, State.Files, H, (65, 100, 97), Count, S);
      Require (S = Success and Count = 3, "tmpfs write");
      IO.Handles.Close (State.Handles, H, S);
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
   end Run;
end AxiomOS.Kernel.Selftest;
