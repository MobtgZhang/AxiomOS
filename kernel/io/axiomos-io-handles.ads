package AxiomOS.IO.Handles with Preelaborate is
   function Resolve (Table : Handle_Table; Value : Handle) return Natural;
   procedure Open (Table : in out Handle_Table; FS : in out VFS.File_System;
                   Path : String; Permissions : Rights;
                   Value : out Handle; Result : out Status);
   procedure Close (Table : in out Handle_Table; Value : Handle;
                    Result : out Status);
end AxiomOS.IO.Handles;
