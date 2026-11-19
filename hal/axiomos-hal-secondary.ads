with AxiomOS.Types; use AxiomOS.Types;
with AxiomOS.Boot.Protocol;
with AxiomOS.Firmware.ACPI;
package AxiomOS.HAL.Secondary is
   function Bootstrap_Id return U64
     with Import, Convention => C, External_Name => "axiom_bootstrap_id";
   function Ticks return U64
     with Import, Convention => C, External_Name => "axiom_ticks";
   procedure Enumerate (Info : Boot.Protocol.Boot_Info;
                         List : out Firmware.ACPI.Topology; Result : out Status);
   -- Context is a 4 KiB, identity mapped, kernel-owned page.
   procedure Start (Hardware_Id, Context : U64; Result : out Status);
end AxiomOS.HAL.Secondary;
