with AxiomOS.Types; use AxiomOS.Types;
package AxiomOS.Runtime is
   function Memcpy (Target, Source, Length : U64) return U64
     with Export, Convention => C, External_Name => "memcpy";
   function Memmove (Target, Source, Length : U64) return U64
     with Export, Convention => C, External_Name => "memmove";
   function Memset (Target : U64; Value : Integer; Length : U64) return U64
     with Export, Convention => C, External_Name => "memset";
   function Memcmp (Left, Right, Length : U64) return Integer
     with Export, Convention => C, External_Name => "memcmp";
   procedure Last_Chance (Message : U64; Line : Integer)
     with Export, Convention => C, External_Name => "__gnat_last_chance_handler",
       No_Return;
end AxiomOS.Runtime;
