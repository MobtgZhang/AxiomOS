with AxiomOS.Types; use AxiomOS.Types;
package AxiomOS.Architecture with Pure is
   Name : constant String := "riscv64";
   ELF_Machine : constant U16 := 243;
   Relative_Relocation : constant U64 := 3;
   EFI_File : constant String := "BOOTRISCV64.EFI";
end AxiomOS.Architecture;
