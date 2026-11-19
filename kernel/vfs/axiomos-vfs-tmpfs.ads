package AxiomOS.VFS.Tmpfs with Preelaborate is
   procedure Initialize (FS : in out File_System);
   procedure Lookup (FS : File_System; Path : String;
                     Id : out Node_Id; Result : out Status);
   procedure Create (FS : in out File_System; Path : String;
                     Kind : Node_Kind; Id : out Node_Id; Result : out Status);
   procedure Read (FS : File_System; Id : Node_Id; Offset : U64;
                   Buffer : out Bytes; Count : out Natural; Result : out Status);
   procedure Write (FS : in out File_System; Id : Node_Id; Offset : U64;
                    Buffer : Bytes; Count : out Natural; Result : out Status);
end AxiomOS.VFS.Tmpfs;
