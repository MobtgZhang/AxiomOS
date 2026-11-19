package AxiomOS.IO.Streams with Preelaborate is
   procedure Read (Table : in out Handle_Table; FS : VFS.File_System;
                   Value : Handle; Buffer : out Bytes; Count : out Natural;
                   Result : out Status);
   procedure Write (Table : in out Handle_Table; FS : in out VFS.File_System;
                    Value : Handle; Buffer : Bytes; Count : out Natural;
                    Result : out Status);
end AxiomOS.IO.Streams;
