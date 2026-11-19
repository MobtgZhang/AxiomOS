with AxiomOS.Types; use AxiomOS.Types;
package AxiomOS.Firmware.ACPI is
   type CPU_Description is record
      Hardware_Id : U64 := 0;
      Enabled : Boolean := False;
   end record;
   type CPU_Array is array (Natural range 0 .. 63) of CPU_Description;
   type Topology is record
      CPUs : CPU_Array;
      Count : Natural := 0;
      Local_APIC : U64 := 16#FEE0_0000#;
   end record;
end AxiomOS.Firmware.ACPI;
