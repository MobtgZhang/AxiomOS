package body AxiomOS.Storage.Endian is
   use type U8, U64;
   function LE (Data : Bytes; Offset, Count : Natural) return U64 is
      Value : U64 := 0;
   begin
      if Count > 8 or else Offset > Data'Length or else Count > Data'Length - Offset then return 0; end if;
      for I in reverse 0 .. Integer (Count) - 1 loop
         Value := Value * 256 + U64 (Data (Data'First + Offset + I));
      end loop;
      return Value;
   end LE;
   function Text (Data : Bytes; Offset : Natural; Value : String) return Boolean is
   begin
      if Offset > Data'Length or else Value'Length > Data'Length - Offset then return False; end if;
      for I in Value'Range loop
         if Data (Data'First + Offset + I - Value'First) /= Character'Pos (Value (I)) then return False; end if;
      end loop;
      return True;
   end Text;
   function Equal_Name (Left, Right : String) return Boolean is
      function Fold (C : Character) return Character is
        (if C in 'a' .. 'z' then Character'Val (Character'Pos (C) - 32) else C);
   begin
      if Left'Length /= Right'Length then return False; end if;
      for I in 0 .. Left'Length - 1 loop
         if Fold (Left (Left'First + I)) /= Fold (Right (Right'First + I)) then return False; end if;
      end loop;
      return True;
   end Equal_Name;
end AxiomOS.Storage.Endian;
