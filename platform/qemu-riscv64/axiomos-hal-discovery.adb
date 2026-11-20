with AxiomOS.Firmware.ACPI.Tables;
with AxiomOS.Firmware.DeviceTree;
package body AxiomOS.HAL.Discovery is
   procedure Enumerate (Info : Boot.Protocol.Boot_Info;
                         List : out Firmware.ACPI.Topology; Result : out Status) is
   begin
      Firmware.DeviceTree.CPUs (Info.Device_Tree, List, Result);
      if Result = Not_Found then Firmware.ACPI.Tables.Parse_Topology (Info.ACPI, List, Result); end if;
   end Enumerate;
end AxiomOS.HAL.Discovery;
