with AxiomOS.Firmware.ACPI;
with AxiomOS.HAL.Secondary;
with AxiomOS.HAL.Discovery;
with AxiomOS.HAL.Clock;
with AxiomOS.HAL.CPU;
with AxiomOS.HAL.Console;
with AxiomOS.SMP.Topology;
with AxiomOS.SMP.Startup;
with AxiomOS.SMP.Locks;
with AxiomOS.SMP.Work;
with AxiomOS.Raw;
package body AxiomOS.SMP.Bringup is
   use type U32, U64;
   type Flags is array (CPU_Index) of aliased U32 with Atomic_Components;
   Online_Flags : Flags;
   Lock : Locks.Spinlock;
   Counter : U64;
   Gate : aliased U32 with Atomic;
   procedure Wait_Gate (CPU : CPU_Index; Argument : U64; Result : out Status) is
      pragma Unreferenced (CPU, Argument);
   begin
      while Gate = 0 loop HAL.CPU.Pause; end loop;
      HAL.CPU.Fence; Result := Success;
   end Wait_Gate;
   procedure Worker (Index : U64)
     with Export, Convention => C, External_Name => "axiom_secondary", No_Return;
   procedure Worker (Index : U64) is
      Ignore : U32;
   begin
      if Index >= Max_CPUs then HAL.CPU.Halt; end if;
      Ignore := HAL.CPU.Exchange (Raw.Number (Online_Flags (CPU_Index (Index))'Address), 1);
      Work.Serve (CPU_Index (Index));
   end Worker;
   procedure Increment (CPU : CPU_Index; Argument : U64; Result : out Status) is
      pragma Unreferenced (CPU);
   begin
      for I in 1 .. Argument loop
         Locks.Acquire (Lock); Counter := Counter + 1; Locks.Release (Lock);
      end loop;
      Result := Success;
   end Increment;
   procedure Initialize (Info : Boot.Protocol.Boot_Info;
                         Pages : in out Memory.Physical.Allocator;
                         CPUs : in out Manager; Result : out Status) is
      List : Firmware.ACPI.Topology;
      BSP : constant U64 := HAL.Secondary.Boot_CPU (Info);
      Index : CPU_Index;
      Context, Stack, First : U64;
      S : Status;
      Found_BSP : Boolean := False;
      Jobs : array (CPU_Index) of Work.Ticket;
      Extra : Work.Ticket;
      Done : Boolean;
      Ignore : U32;
   begin
      CPUs := (others => <>);
      Work.Initialize; Locks.Initialize (Lock); Counter := 0;
      Online_Flags := (others => 0);
      Topology.Register_CPU (CPUs, BSP, True, Index, Result);
      if Result /= Success then return; end if;
      HAL.Discovery.Enumerate (Info, List, Result);
      if Result /= Success then return; end if;
      if List.Count = 0 then Result := Not_Found; return; end if;
      for I in 0 .. List.Count - 1 loop
         if List.CPUs (I).Hardware_Id = BSP then Found_BSP := True; end if;
      end loop;
      if not Found_BSP then Result := Corrupt; return; end if;
      if List.Count > 1 then
         HAL.Secondary.Prepare (Info, Pages, Result);
         if Result /= Success then return; end if;
      end if;
      for I in 0 .. List.Count - 1 loop
         if List.CPUs (I).Hardware_Id /= BSP then
            Topology.Register_CPU (CPUs, List.CPUs (I).Hardware_Id, False, Index, Result);
            if Result /= Success then return; end if;
            Memory.Physical.Allocate (Pages, 1, Page_Size, Memory.Physical.Kernel, Context, Result);
            if Result /= Success then return; end if;
            Memory.Physical.Allocate (Pages, 8, Page_Size, Memory.Physical.Kernel, Stack, Result);
            if Result /= Success then
               Memory.Physical.Release (Pages, Context, 1, S); return;
            end if;
            Raw.Zero (Context, Page_Size);
            Raw.Store64 (Context, Stack + 8 * Page_Size);
            Raw.Store64 (Context + 8, U64 (Index));
            First := HAL.Clock.Now;
            Startup.Begin_Start (CPUs, Index, First, 5_000_000, Result);
            if Result /= Success then return; end if;
            HAL.CPU.Fence;
            HAL.Secondary.Start (List.CPUs (I).Hardware_Id, Context, Result);
            -- Once a hardware start was issued, stack/context remain pinned
            -- even on timeout: a delayed CPU may still access them.
            if Result /= Success then CPUs.CPUs (Index).State := Failed; return; end if;
            while Online_Flags (Index) = 0 loop
               if HAL.Clock.Now - First > 5_000_000 then
                  CPUs.CPUs (Index).State := Failed; Result := Timed_Out; return;
               end if;
               HAL.CPU.Pause;
            end loop;
            HAL.CPU.Fence;
            Startup.Acknowledge (CPUs, Index, Result);
            if Result /= Success then return; end if;
            Work.Enable (Index);
            HAL.Console.Line ("AXIOM:SMP:AP:ONLINE");
         end if;
      end loop;
      -- Two waves prove that CPUs continue serving new work after startup.
      for Wave in 1 .. 2 loop
         for I in 1 .. CPUs.Count - 1 loop
            Work.Submit (I, Increment'Access, 1000, Jobs (I), Result);
            if Result /= Success then return; end if;
            Work.Submit (I, Increment'Access, 1000, Extra, Result);
            if Result /= Busy then Result := Corrupt; return; end if;
         end loop;
         Increment (CPUs.Bootstrap, U64 (CPUs.Count - 1) * 1000, S);
         for I in 1 .. CPUs.Count - 1 loop
            Work.Wait (Jobs (I), 5_000_000, Result);
            if Result /= Success then return; end if;
            Work.Collect (Jobs (I), Result, Done);
            if Result /= Bad_Handle or else Done then Result := Corrupt; return; end if;
         end loop;
      end loop;
      if Counter /= U64 (CPUs.Count - 1) * 4000 then Result := Corrupt; return; end if;
      if CPUs.Count > 1 then
         Gate := 0;
         Work.Submit (1, Wait_Gate'Access, 0, Extra, Result);
         if Result /= Success then return; end if;
         Work.Wait (Extra, 1_000, Result);
         if Result /= Timed_Out then Result := Corrupt; return; end if;
         Ignore := HAL.CPU.Exchange (Raw.Number (Gate'Address), 1);
         Work.Wait (Extra, 5_000_000, Result);
         if Result /= Success then return; end if;
      end if;
      HAL.Console.Line ("AXIOM:SMP:WORK:PASS");
      HAL.Console.Line ("AXIOM:SMP:HARDWARE:PASS");
      Result := Success;
   end Initialize;
end AxiomOS.SMP.Bringup;
