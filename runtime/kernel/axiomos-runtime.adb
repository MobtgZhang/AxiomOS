with AxiomOS.Raw;
with AxiomOS.HAL.Console;
package body AxiomOS.Runtime is
   use type U64, U8;
   function Memcpy (Target, Source, Length : U64) return U64 is
   begin Raw.Copy (Target, Source, Length); return Target; end Memcpy;
   function Memmove (Target, Source, Length : U64) return U64 is
   begin
      if Length > 0 and then Target > Source then
         for I in reverse 0 .. Length - 1 loop
            Raw.Store8 (Target + I, Raw.Load8 (Source + I));
         end loop;
      else Raw.Copy (Target, Source, Length);
      end if;
      return Target;
   end Memmove;
   function Memset (Target : U64; Value : Integer; Length : U64) return U64 is
   begin
      if Length > 0 then
         for I in 0 .. Length - 1 loop
            Raw.Store8 (Target + I, U8 (Value mod 256));
         end loop;
      end if;
      return Target;
   end Memset;
   function Memcmp (Left, Right, Length : U64) return Integer is
      A, B : U8;
   begin
      if Length > 0 then
         for I in 0 .. Length - 1 loop
            A := Raw.Load8 (Left + I);
            B := Raw.Load8 (Right + I);
            if A /= B then return Integer (A) - Integer (B); end if;
         end loop;
      end if;
      return 0;
   end Memcmp;
   procedure Last_Chance (Message : U64; Line : Integer) is
      pragma Unreferenced (Message, Line);
   begin HAL.Console.Panic ("Ada runtime check"); end Last_Chance;
end AxiomOS.Runtime;
