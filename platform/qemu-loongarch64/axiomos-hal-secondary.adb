with AxiomOS.Firmware.ACPI.Tables;
package body AxiomOS.HAL.Secondary is
   use type U64;
   procedure CPU_On (Hardware_Id, Context : U64)
     with Import, Convention => C, External_Name => "axiom_cpu_on";
   procedure Enumerate (Info : Boot.Protocol.Boot_Info;
                         List : out Firmware.ACPI.Topology; Result : out Status) is
   begin Firmware.ACPI.Tables.Parse_Topology (Info.ACPI, List, Result); end Enumerate;
   procedure Start (Hardware_Id, Context : U64; Result : out Status) is
   begin
      if Hardware_Id > 1023 then Result := Unsupported; return; end if;
      CPU_On (Hardware_Id, Context); Result := Success;
   end Start;
end AxiomOS.HAL.Secondary;
