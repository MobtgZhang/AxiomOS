with System;
with AxiomOS.Types; use AxiomOS.Types;
package AxiomOS.Raw with Preelaborate is
   function Address (Value : U64) return System.Address;
   function Number (Value : System.Address) return U64;
   function Load8 (Base : U64) return U8;
   function Load16 (Base : U64) return U16;
   function Load32 (Base : U64) return U32;
   function Load64 (Base : U64) return U64;
   procedure Store8 (Base : U64; Value : U8);
   procedure Store16 (Base : U64; Value : U16);
   procedure Store32 (Base : U64; Value : U32);
   procedure Store64 (Base : U64; Value : U64);
   procedure Zero (Base, Length : U64);
   procedure Copy (Target, Source, Length : U64);
end AxiomOS.Raw;
