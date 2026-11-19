with AxiomOS.Types; use AxiomOS.Types;
package AxiomOS.Architecture with Pure is
   Name : constant String := "x86_64";
   ELF_Machine : constant U16 := 62;
   Relative_Relocation : constant U64 := 8;
   EFI_File : constant String := "BOOTX64.EFI";
end AxiomOS.Architecture;
