with AxiomOS.X86;
with AxiomOS.Raw;
with AxiomOS.Firmware.ACPI.Tables;
with AxiomOS.HAL.Clock;
with AxiomOS.HAL.CPU;
package body AxiomOS.HAL.Secondary is
   use type U32, U64;
   Trampoline : aliased U8 with Import, External_Name => "axiom_ap_trampoline";
   Entry_Point : aliased U8 with Import, External_Name => "axiom_secondary";
   Base, LAPIC : U64;
   function Boot_CPU (Info : Boot.Protocol.Boot_Info) return U64 is
      pragma Unreferenced (Info);
   begin return U64 (X86.APIC_Id); end Boot_CPU;
   procedure Prepare (Info : Boot.Protocol.Boot_Info;
                      Pages : in out Memory.Physical.Allocator; Result : out Status) is
      Description : Firmware.ACPI.Topology;
      S : Status;
   begin
      Base := 0; LAPIC := 0;
      Firmware.ACPI.Tables.Parse_Topology (Info.ACPI, Description, Result);
      if Result /= Success then return; end if;
      LAPIC := Description.Local_APIC;
      if LAPIC = 0 or else not Aligned (LAPIC, Page_Size) then Result := Corrupt; return; end if;
      Memory.Physical.Allocate_Below (Pages, 1, Page_Size, 16#A0000#,
                                      Memory.Physical.Kernel, Base, Result);
      if Result /= Success then return; end if;
      Raw.Zero (Base, Page_Size);
      Raw.Copy (Base, Raw.Number (Trampoline'Address), 16#230#);
      Raw.Store32 (Base + 16#1E2#, U32 (Base + 16#1C0#));
      Raw.Store32 (Base + 16#1E8#, Raw.Load32 (Base + 16#1E8#) + U32 (Base));
      Raw.Store32 (Base + 16#1F0#, Raw.Load32 (Base + 16#1F0#) + U32 (Base));
      Raw.Store64 (Base + 16#200#, X86.Read_CR3);
      Raw.Store64 (Base + 16#208#, X86.Read_CR4);
      Raw.Store64 (Base + 16#210#, X86.Read_EFER);
      Raw.Store64 (Base + 16#220#, Raw.Number (Entry_Point'Address));
      Result := Success;
   end Prepare;
   procedure Start (Hardware_Id, Context : U64; Result : out Status) is
      function ICR (Command : U32) return Boolean is
         function Wait_Idle return Boolean is
            First : constant U64 := Clock.Now;
         begin
            while (Raw.Load32 (LAPIC + 16#300#) and 16#1000#) /= 0 loop
               if Clock.Now - First > 1_000_000 then return False; end if;
               CPU.Pause;
            end loop;
            return True;
         end Wait_Idle;
      begin
         if not Wait_Idle then return False; end if;
         Raw.Store32 (LAPIC + 16#310#, U32 (Hardware_Id) * 2 ** 24);
         Raw.Store32 (LAPIC + 16#300#, Command);
         return Wait_Idle;
      end ICR;
   begin
      Result := Invalid_Argument;
      if Base = 0 or else Context = 0 then return; end if;
      if Hardware_Id > 255 then Result := Unsupported; return; end if;
      Raw.Store64 (Base + 16#218#, Raw.Load64 (Context));
      Raw.Store64 (Base + 16#228#, Raw.Load64 (Context + 8));
      CPU.Fence;
      Result := Timed_Out;
      if not ICR (16#C500#) then return; end if;
      Clock.Delay_US (10_000);
      if not ICR (16#8500#) then return; end if;
      Clock.Delay_US (200);
      if not ICR (16#600# + U32 (Base / Page_Size)) then return; end if;
      Clock.Delay_US (200);
      if not ICR (16#600# + U32 (Base / Page_Size)) then return; end if;
      Result := Success;
   end Start;
end AxiomOS.HAL.Secondary;
