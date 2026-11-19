with AxiomOS.Types; use AxiomOS.Types;
package AxiomOS.HAL.Console is
   procedure Put (Text : String);
   procedure Line (Text : String);
   procedure Hex (Value : U64);
   procedure Panic (Text : String) with No_Return;
end AxiomOS.HAL.Console;
