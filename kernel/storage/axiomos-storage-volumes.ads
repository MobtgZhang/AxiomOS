package AxiomOS.Storage.Volumes with Preelaborate is
   procedure Mount (Disk : Device; V : out Volume; Result : out Status);
   procedure Lookup (V : Volume; Path : String; Item : out File_Object; Result : out Status);
   procedure Read_File (V : Volume; Item : File_Object; Offset : U64;
                        Buffer : out Bytes; Count : out Natural; Result : out Status);
end AxiomOS.Storage.Volumes;
