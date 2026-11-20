with AxiomOS.Types; use AxiomOS.Types;
with AxiomOS.Firmware.ACPI;
package AxiomOS.Firmware.DeviceTree is
   function Timebase (Base : U64) return U64;
   procedure CPUs (Base : U64; List : out ACPI.Topology; Result : out Status);
end AxiomOS.Firmware.DeviceTree;
