with AxiomOS.Types; use AxiomOS.Types;
package AxiomOS.Kernel.Main is
   procedure Entry_Point (Info_Address : U64)
     with Export, Convention => C, External_Name => "axiom_kernel_entry", No_Return;
end AxiomOS.Kernel.Main;
