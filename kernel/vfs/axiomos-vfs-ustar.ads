package AxiomOS.VFS.Ustar with Preelaborate is
   procedure Mount_Ustar (FS : in out File_System; Archive : Bytes;
                          Result : out Status);
end AxiomOS.VFS.Ustar;
