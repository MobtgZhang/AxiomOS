with System.Storage_Elements;
package body AxiomOS.Raw is
   use type U64;
   function Address (Value : U64) return System.Address is
     (System.Storage_Elements.To_Address
        (System.Storage_Elements.Integer_Address (Value)));
   function Number (Value : System.Address) return U64 is
     (U64 (System.Storage_Elements.To_Integer (Value)));
   function Load8 (Base : U64) return U8 is
      V : U8 with Import, Address => Address (Base), Volatile;
   begin return V; end Load8;
   function Load16 (Base : U64) return U16 is
      V : U16 with Import, Address => Address (Base), Volatile;
   begin return V; end Load16;
   function Load32 (Base : U64) return U32 is
      V : U32 with Import, Address => Address (Base), Volatile;
   begin return V; end Load32;
   function Load64 (Base : U64) return U64 is
      V : U64 with Import, Address => Address (Base), Volatile;
   begin return V; end Load64;
   procedure Store8 (Base : U64; Value : U8) is
      V : U8 with Import, Address => Address (Base), Volatile;
   begin V := Value; end Store8;
   procedure Store16 (Base : U64; Value : U16) is
      V : U16 with Import, Address => Address (Base), Volatile;
   begin V := Value; end Store16;
   procedure Store32 (Base : U64; Value : U32) is
      V : U32 with Import, Address => Address (Base), Volatile;
   begin V := Value; end Store32;
   procedure Store64 (Base : U64; Value : U64) is
      V : U64 with Import, Address => Address (Base), Volatile;
   begin V := Value; end Store64;
   procedure Zero (Base, Length : U64) is
   begin
      if Length = 0 then return; end if;
      for I in 0 .. Length - 1 loop Store8 (Base + I, 0); end loop;
   end Zero;
   procedure Copy (Target, Source, Length : U64) is
   begin
      if Length = 0 then return; end if;
      for I in 0 .. Length - 1 loop Store8 (Target + I, Load8 (Source + I)); end loop;
   end Copy;
end AxiomOS.Raw;
