package AxiomOS.IO.Streams with Preelaborate is
   type Seek_Origin is (Beginning, Current, Ending);
   procedure Seek (Table : in out Handle_Table; FS : VFS.File_System;
                   Value : Handle; Offset : I64; Origin : Seek_Origin;
                   Position : out U64; Result : out Status);
   procedure Stat (Table : Handle_Table; FS : VFS.File_System; Value : Handle;
                   Length : out U64; Kind : out VFS.Node_Kind; Result : out Status);
   procedure Read (Table : in out Handle_Table; FS : VFS.File_System;
                   Value : Handle; Buffer : out Bytes; Count : out Natural;
                   Result : out Status);
   procedure Write (Table : in out Handle_Table; FS : in out VFS.File_System;
                    Value : Handle; Buffer : Bytes; Count : out Natural;
                    Result : out Status);
end AxiomOS.IO.Streams;
