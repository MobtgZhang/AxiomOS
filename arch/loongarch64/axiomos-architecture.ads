with AxiomOS.Types; use AxiomOS.Types;
package AxiomOS.Architecture with Pure is
   Name : constant String := "loongarch64";
   ELF_Machine : constant U16 := 258;
   Relative_Relocation : constant U64 := 3;
   EFI_File : constant String := "BOOTLOONGARCH64.EFI";
end AxiomOS.Architecture;
