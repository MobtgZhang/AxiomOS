package AxiomOS.Firmware.UEFI.Files is
   procedure Load (Path : String; Base, Length : out U64; Result : out Status);
end AxiomOS.Firmware.UEFI.Files;
