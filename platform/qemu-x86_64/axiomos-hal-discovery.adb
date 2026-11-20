with AxiomOS.Firmware.ACPI.Tables;
package body AxiomOS.HAL.Discovery is
   procedure Enumerate (Info : Boot.Protocol.Boot_Info;
                        List : out Firmware.ACPI.Topology; Result : out Status) is
   begin Firmware.ACPI.Tables.Parse_Topology (Info.ACPI, List, Result); end Enumerate;
end AxiomOS.HAL.Discovery;
