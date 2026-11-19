with AxiomOS.Types; use AxiomOS.Types;
package AxiomOS.Boot.Images is
   procedure Load_Kernel (File_Base, File_Size : U64;
                          Base, Size, Entry_Point : out U64;
                          Result : out Status);
end AxiomOS.Boot.Images;
