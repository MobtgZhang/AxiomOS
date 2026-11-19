with AxiomOS.Types; use AxiomOS.Types;
package AxiomOS.X86 is
   function APIC_Id return U32 with Import, Convention => C, External_Name => "axiom_apic_id";
   function Read_CR3 return U64 with Import, Convention => C, External_Name => "axiom_read_cr3";
   function Read_CR4 return U64 with Import, Convention => C, External_Name => "axiom_read_cr4";
   function Read_EFER return U64 with Import, Convention => C, External_Name => "axiom_read_efer";
   procedure Write_CR3 (Value : U64) with Import, Convention => C, External_Name => "axiom_write_cr3";
   function Ticks return U64 with Import, Convention => C, External_Name => "axiom_ticks";
end AxiomOS.X86;
