with AxiomOS.Firmware.ACPI;
with AxiomOS.Architecture;
with AxiomOS.HAL.Secondary;
with AxiomOS.HAL.CPU;
with AxiomOS.HAL.Console;
with AxiomOS.SMP.Topology;
with AxiomOS.SMP.Startup;
with AxiomOS.SMP.Locks;
with AxiomOS.Raw;
package body AxiomOS.SMP.Bringup is
   use type U16, U32, U64;
   Lock : Locks.Spinlock;
   Online_Flag, Completed : aliased U32 with Atomic;
   Counter : U64 with Volatile;
   procedure Worker (Index : U64)
     with Export, Convention => C, External_Name => "axiom_secondary", No_Return;
   procedure Worker (Index : U64) is
      Ignore : U32;
   begin
      Ignore := HAL.CPU.Exchange (Raw.Number (Online_Flag'Address), U32 (Index) + 1);
      for I in 1 .. 1000 loop
         Locks.Acquire (Lock); Counter := Counter + 1; Locks.Release (Lock);
      end loop;
      Ignore := HAL.CPU.Exchange (Raw.Number (Completed'Address), 1);
      HAL.CPU.Halt;
   end Worker;
   procedure Initialize (Info : Boot.Protocol.Boot_Info;
                         Pages : in out Memory.Physical.Allocator;
                         CPUs : in out Manager; Result : out Status) is
      List : Firmware.ACPI.Topology;
      BSP : constant U64 := (if Architecture.ELF_Machine = 243 then Info.Bootstrap_CPU else HAL.Secondary.Bootstrap_Id);
      Index : CPU_Index;
      Context, Stack, Start_Time : U64;
      S : Status;
      Found_BSP : Boolean := False;
   begin
      CPUs := (others => <>);
      Locks.Initialize (Lock); Counter := 0; Online_Flag := 0; Completed := 0;
      Topology.Register_CPU (CPUs, BSP, True, Index, S);
      if S /= Success then Result := S; return; end if;
      HAL.Secondary.Enumerate (Info, List, Result);
      HAL.Console.Put ("SMP BSP="); HAL.Console.Hex (BSP);
      HAL.Console.Put (" count="); HAL.Console.Hex (U64 (List.Count));
      HAL.Console.Put (" status="); HAL.Console.Hex (U64 (Status'Pos (Result))); HAL.Console.Line ("");
      if Result /= Success then return; end if;
      if List.Count = 0 then Result := Not_Found; return; end if;
      for I in 0 .. List.Count - 1 loop
         if List.CPUs (I).Hardware_Id = BSP then Found_BSP := True; end if;
      end loop;
      if not Found_BSP then Result := Corrupt; return; end if;
      for I in 0 .. List.Count - 1 loop
         if List.CPUs (I).Hardware_Id /= BSP then
            Topology.Register_CPU (CPUs, List.CPUs (I).Hardware_Id, False, Index, Result);
            if Result /= Success then return; end if;
            Memory.Physical.Allocate (Pages, 1, 4096, Memory.Physical.Kernel, Context, Result);
            if Result /= Success then return; end if;
            Memory.Physical.Allocate (Pages, 8, 4096, Memory.Physical.Kernel, Stack, Result);
            if Result /= Success then
               Memory.Physical.Release (Pages, Context, 1, S);
               return;
            end if;
            Raw.Zero (Context, 4096);
            Raw.Store64 (Context, Stack + 8 * 4096);
            Raw.Store64 (Context + 8, U64 (Index));
            Online_Flag := 0; Completed := 0;
            Startup.Begin_Start (CPUs, Index, 0, U64'Last, Result);
            if Result /= Success then return; end if;
            HAL.Secondary.Start (List.CPUs (I).Hardware_Id, Context, Result);
            HAL.Console.Put ("SMP start hart="); HAL.Console.Hex (List.CPUs (I).Hardware_Id);
            HAL.Console.Put (" status="); HAL.Console.Hex (U64 (Status'Pos (Result))); HAL.Console.Line ("");
            if Result /= Success then return; end if;
            Start_Time := HAL.Secondary.Ticks;
            while Online_Flag = 0 loop
               if HAL.Secondary.Ticks - Start_Time > 500_000_000 then
                  Result := Timed_Out; return;
               end if;
               HAL.CPU.Pause;
            end loop;
            if Online_Flag /= U32 (Index) + 1 then Result := Corrupt; return; end if;
            Startup.Acknowledge (CPUs, Index, Result);
            if Result /= Success then return; end if;
            for J in 1 .. 1000 loop
               Locks.Acquire (Lock); Counter := Counter + 1; Locks.Release (Lock);
            end loop;
            while Completed = 0 loop
               if HAL.Secondary.Ticks - Start_Time > 500_000_000 then Result := Timed_Out; return; end if;
               HAL.CPU.Pause;
            end loop;
            HAL.Console.Line ("AXIOM:SMP:AP:ONLINE");
         end if;
      end loop;
      if Counter /= U64 (CPUs.Count - 1) * 2000 then Result := Corrupt; return; end if;
      HAL.Console.Line ("AXIOM:SMP:HARDWARE:PASS");
      Result := Success;
   end Initialize;
end AxiomOS.SMP.Bringup;
