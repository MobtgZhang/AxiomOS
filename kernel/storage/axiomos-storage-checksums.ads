package AxiomOS.Storage.Checksums with Preelaborate is
   function CRC32C (Data : Bytes; Seed : U32 := U32'Last) return U32;
end AxiomOS.Storage.Checksums;
