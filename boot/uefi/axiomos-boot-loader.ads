with AxiomOS.Types; use AxiomOS.Types;
package AxiomOS.Boot.Loader is
   function Main (Image, Table : U64) return U64
     with Export, Convention => C, External_Name => "axiom_efi_main";
end AxiomOS.Boot.Loader;
