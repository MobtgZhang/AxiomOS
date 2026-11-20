with AxiomOS.Types; use AxiomOS.Types;
with AxiomOS.Boot.Protocol;
with AxiomOS.Firmware.ACPI;
package AxiomOS.HAL.Discovery is
   procedure Enumerate (Info : Boot.Protocol.Boot_Info;
                        List : out Firmware.ACPI.Topology; Result : out Status);
end AxiomOS.HAL.Discovery;
