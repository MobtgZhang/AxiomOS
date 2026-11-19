package body AxiomOS.Storage.Checksums is
   use type U32;
   function CRC32C (Data : Bytes; Seed : U32 := U32'Last) return U32 is
      Value : U32 := Seed;
   begin
      for B of Data loop
         Value := Value xor U32 (B);
         for Bit in 1 .. 8 loop
            Value := (Value / 2) xor (if (Value and 1) = 1 then 16#82F63B78# else 0);
         end loop;
      end loop;
      return Value;
   end CRC32C;
end AxiomOS.Storage.Checksums;
