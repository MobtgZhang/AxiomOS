with AxiomOS.Firmware.DeviceTree;
with AxiomOS.Firmware.ACPI.Tables;
package body AxiomOS.HAL.Secondary is
   use type U64;
   function CPU_On (Hardware_Id, Context : U64) return U64
     with Import, Convention => C, External_Name => "axiom_cpu_on";
   procedure Enumerate (Info : Boot.Protocol.Boot_Info;
                         List : out Firmware.ACPI.Topology; Result : out Status) is
   begin
      Firmware.DeviceTree.CPUs (Info.Device_Tree, List, Result);
      if Result = Not_Found then Firmware.ACPI.Tables.Parse_Topology (Info.ACPI, List, Result); end if;
   end Enumerate;
   procedure Start (Hardware_Id, Context : U64; Result : out Status) is
   begin
      if CPU_On (Hardware_Id, Context) = 0 then Result := Success;
      else Result := IO_Error; end if;
   end Start;
end AxiomOS.HAL.Secondary;
