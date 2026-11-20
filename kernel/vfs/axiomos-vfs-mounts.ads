with AxiomOS.Storage;
package AxiomOS.VFS.Mounts with Preelaborate is
   procedure Mount_Root (FS : in out File_System; Disk : Storage.Device; Result : out Status);
   -- Absolute canonical paths, longest component prefix. The caller serializes
   -- mount, lookup and handle operations on a filesystem instance.
   function Resolve (FS : File_System; Canonical : String) return Mount_Id;
   procedure Mount_Disk (FS : in out File_System; Path : String;
                         Disk : Storage.Device; Result : out Status);
   procedure Mount_Tmpfs (FS : in out File_System; Path : String; Result : out Status);
   procedure Unmount (FS : in out File_System; Path : String; Result : out Status);
   procedure Lookup (FS : in out File_System; Path : String; Id : out Node_Id; Result : out Status);
   procedure Read (FS : File_System; Id : Node_Id; Offset : U64;
                   Buffer : out Bytes; Count : out Natural; Result : out Status);
   procedure Write (FS : in out File_System; Id : Node_Id; Offset : U64;
                    Buffer : Bytes; Count : out Natural; Result : out Status);
end AxiomOS.VFS.Mounts;
