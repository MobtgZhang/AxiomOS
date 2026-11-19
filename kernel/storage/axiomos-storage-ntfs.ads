package AxiomOS.Storage.NTFS with Preelaborate is
   procedure Mount (V : in out Volume; Result : out Status);
   procedure Child (V : Volume; Parent : File_Object; Name : String;
                    Item : out File_Object; Result : out Status);
   procedure Read_File (V : Volume; Item : File_Object; Offset : U64;
                        Buffer : out Bytes; Count : out Natural; Result : out Status);
end AxiomOS.Storage.NTFS;
