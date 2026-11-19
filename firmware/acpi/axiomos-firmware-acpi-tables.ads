package AxiomOS.Firmware.ACPI.Tables is
   procedure Find (RSDP : U64; Signature : U32; Table : out U64; Result : out Status);
   procedure Parse_Topology (RSDP : U64; Description : out Topology;
                             Result : out Status);
end AxiomOS.Firmware.ACPI.Tables;
