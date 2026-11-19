package body AxiomOS.Storage is
   use type U64;
   procedure Read (Disk : Device; Offset : U64; Buffer : out Bytes; Result : out Status) is
   begin
      Buffer := (others => 0);
      Result := Invalid_Argument;
      if Disk.Read = null or else Offset > Disk.Length or else
        U64 (Buffer'Length) > Disk.Length - Offset or else
        Disk.Base > U64'Last - Offset then return; end if;
      Disk.Read (Disk.Base + Offset, Buffer, Result);
   end Read;
end AxiomOS.Storage;
