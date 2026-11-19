package AxiomOS.Storage.Endian with Preelaborate is
   function LE (Data : Bytes; Offset, Count : Natural) return U64;
   function Text (Data : Bytes; Offset : Natural; Value : String) return Boolean;
   function Equal_Name (Left, Right : String) return Boolean;
end AxiomOS.Storage.Endian;
