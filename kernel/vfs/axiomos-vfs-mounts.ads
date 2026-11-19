with AxiomOS.Storage;
package AxiomOS.VFS.Mounts with Preelaborate is
   procedure Mount_Root (FS : in out File_System; Disk : Storage.Device; Result : out Status);
   procedure Lookup (FS : in out File_System; Path : String; Id : out Node_Id; Result : out Status);
   procedure Read (FS : File_System; Id : Node_Id; Offset : U64;
                   Buffer : out Bytes; Count : out Natural; Result : out Status);
   procedure Write (FS : in out File_System; Id : Node_Id; Offset : U64;
                    Buffer : Bytes; Count : out Natural; Result : out Status);
end AxiomOS.VFS.Mounts;
