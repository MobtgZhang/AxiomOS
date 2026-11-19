with AxiomOS.X86;
with AxiomOS.Firmware.ACPI.Tables;
with AxiomOS.SMP.Topology;
with AxiomOS.SMP.Startup;
with AxiomOS.SMP.Locks;
with AxiomOS.HAL.CPU;
with AxiomOS.HAL.Console;
with AxiomOS.Raw;
package body AxiomOS.HAL.SMP is
   use type U8, U32, U64;
   Trampoline : aliased U8 with Import, External_Name => "axiom_ap_trampoline";
   Lock : AxiomOS.SMP.Locks.Spinlock;
   Online_Flag : aliased U32 := 0 with Atomic;
   Completed : aliased U32 := 0 with Atomic;
   Counter : U64 := 0 with Volatile;
   procedure AP_Entry (Index : U64)
     with Export, Convention => C, External_Name => "axiom_ap_entry", No_Return;
   procedure AP_Entry (Index : U64) is
      Ignore : U32;
   begin
      Ignore := CPU.Exchange (Raw.Number (Online_Flag'Address), U32 (Index) + 1);
      for I in 1 .. 1000 loop
         AxiomOS.SMP.Locks.Acquire (Lock);
         Counter := Counter + 1;
         AxiomOS.SMP.Locks.Release (Lock);
      end loop;
      Ignore := CPU.Exchange (Raw.Number (Completed'Address), 1);
      CPU.Halt;
   end AP_Entry;
   procedure Wait_Ticks (Ticks : U64) is
      Start : constant U64 := X86.Ticks;
   begin while X86.Ticks - Start < Ticks loop CPU.Pause; end loop; end Wait_Ticks;
   procedure Initialize (Info : Boot.Protocol.Boot_Info;
                         Pages : in out Memory.Physical.Allocator;
                         CPUs : in out AxiomOS.SMP.Manager; Result : out Status) is
      Description : Firmware.ACPI.Topology;
      Index : AxiomOS.SMP.CPU_Index;
      BSP : constant U64 := U64 (X86.APIC_Id);
      Base, Stack, LAPIC, Deadline : U64;
      S : Status;
      Found_BSP : Boolean := False;
      function ICR (Target, Command : U32) return Boolean is
         function Wait_Idle return Boolean is
            Start : constant U64 := X86.Ticks;
         begin
            while (Raw.Load32 (LAPIC + 16#300#) and 16#1000#) /= 0 loop
               if X86.Ticks - Start > 2_000_000_000 then return False; end if;
               CPU.Pause;
            end loop;
            return True;
         end Wait_Idle;
      begin
         if not Wait_Idle then return False; end if;
         Raw.Store32 (LAPIC + 16#310#, Target * 2 ** 24);
         Raw.Store32 (LAPIC + 16#300#, Command);
         return Wait_Idle;
      end ICR;
   begin
      CPUs := (others => <>);
      AxiomOS.SMP.Locks.Initialize (Lock);
      AxiomOS.SMP.Topology.Register_CPU (CPUs, BSP, True, Index, S);
      if S /= Success then Result := S; return; end if;
      Firmware.ACPI.Tables.Parse_Topology (Info.ACPI, Description, Result);
      if Result /= Success then return; end if;
      LAPIC := Description.Local_APIC;
      if Description.Count = 0 or else LAPIC = 0 or else not Aligned (LAPIC, 4096) then
         Result := Corrupt; return;
      end if;
      for I in 0 .. Description.Count - 1 loop
         if Description.CPUs (I).Hardware_Id = BSP then Found_BSP := True; end if;
      end loop;
      if not Found_BSP then Result := Corrupt; return; end if;
      Memory.Physical.Allocate (Pages, 1, 4096, Memory.Physical.Kernel, Base, Result);
      if Result /= Success then return; end if;
      if Base >= 16#A0000# then
         Memory.Physical.Release (Pages, Base, 1, S);
         Result := Unsupported;
         return;
      end if;
      Raw.Zero (Base, 4096);
      Raw.Copy (Base, Raw.Number (Trampoline'Address), 16#230#);
      Raw.Store32 (Base + 16#1E2#, U32 (Base + 16#1C0#));
      Raw.Store32 (Base + 16#1E8#, Raw.Load32 (Base + 16#1E8#) + U32 (Base));
      Raw.Store32 (Base + 16#1F0#, Raw.Load32 (Base + 16#1F0#) + U32 (Base));
      Raw.Store64 (Base + 16#200#, X86.Read_CR3);
      Raw.Store64 (Base + 16#208#, X86.Read_CR4);
      Raw.Store64 (Base + 16#210#, X86.Read_EFER);
      Raw.Store64 (Base + 16#220#, Raw.Number (AP_Entry'Address));
      Counter := 0;
      for I in 0 .. Description.Count - 1 loop
         if Description.CPUs (I).Hardware_Id /= BSP then
            if Description.CPUs (I).Hardware_Id > 255 then Result := Unsupported; return; end if;
            AxiomOS.SMP.Topology.Register_CPU
              (CPUs, Description.CPUs (I).Hardware_Id, False, Index, Result);
            if Result /= Success then return; end if;
            Memory.Physical.Allocate (Pages, 8, 4096, Memory.Physical.Kernel, Stack, Result);
            if Result /= Success then return; end if;
            Raw.Store64 (Base + 16#218#, Stack + 8 * 4096);
            Raw.Store64 (Base + 16#228#, U64 (Index));
            Online_Flag := 0; Completed := 0;
            AxiomOS.SMP.Startup.Begin_Start (CPUs, Index, X86.Ticks, 2_000_000_000, Result);
            if Result /= Success then return; end if;
            if not ICR (U32 (Description.CPUs (I).Hardware_Id), 16#C500#) then
               Result := Timed_Out; return;
            end if;
            Wait_Ticks (30_000_000);
            if not ICR (U32 (Description.CPUs (I).Hardware_Id), 16#8500#) then
               Result := Timed_Out; return;
            end if;
            Wait_Ticks (1_000_000);
            if not ICR (U32 (Description.CPUs (I).Hardware_Id), 16#600# + U32 (Base / 4096)) then
               Result := Timed_Out; return;
            end if;
            Wait_Ticks (1_000_000);
            if Online_Flag = 0 then
               if not ICR (U32 (Description.CPUs (I).Hardware_Id), 16#600# + U32 (Base / 4096)) then
                  Result := Timed_Out; return;
               end if;
            end if;
            Deadline := X86.Ticks;
            loop
               exit when Online_Flag /= 0;
               if X86.Ticks - Deadline > 2_000_000_000 then Result := Timed_Out; return; end if;
               CPU.Pause;
            end loop;
            if Online_Flag /= U32 (Index) + 1 then Result := Corrupt; return; end if;
            AxiomOS.SMP.Startup.Acknowledge (CPUs, Index, Result);
            if Result /= Success then return; end if;
            for J in 1 .. 1000 loop
               AxiomOS.SMP.Locks.Acquire (Lock);
               Counter := Counter + 1;
               AxiomOS.SMP.Locks.Release (Lock);
            end loop;
            loop
               exit when Completed /= 0;
               if X86.Ticks - Deadline > 2_000_000_000 then Result := Timed_Out; return; end if;
               CPU.Pause;
            end loop;
            Console.Line ("AXIOM:SMP:AP:ONLINE");
         end if;
      end loop;
      if Counter /= U64 (CPUs.Count - 1) * 2000 then Result := Corrupt; return; end if;
      Console.Line ("AXIOM:SMP:HARDWARE:PASS");
      Result := Success;
   end Initialize;
end AxiomOS.HAL.SMP;
