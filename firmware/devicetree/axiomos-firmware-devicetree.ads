with AxiomOS.Types; use AxiomOS.Types;
with AxiomOS.Firmware.ACPI;
package AxiomOS.Firmware.DeviceTree is
   procedure CPUs (Base : U64; List : out ACPI.Topology; Result : out Status);
end AxiomOS.Firmware.DeviceTree;
