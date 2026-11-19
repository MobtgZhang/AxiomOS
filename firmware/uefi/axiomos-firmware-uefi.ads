with AxiomOS.Types; use AxiomOS.Types;
package AxiomOS.Firmware.UEFI is
   subtype EFI_Status is U64;
   EFI_Success : constant EFI_Status := 0;
   Buffer_Too_Small : constant EFI_Status := 16#8000_0000_0000_0005#;
   Invalid_Parameter : constant EFI_Status := 16#8000_0000_0000_0002#;
   Not_Ready : constant EFI_Status := 16#8000_0000_0000_0006#;
   type GUID is record
      A : U32;
      B, C : U16;
      D : U64;
   end record with Convention => C, Size => 128, Alignment => 8;
   -- D stores the last eight GUID bytes in little-endian memory order.
   Loaded_Image_GUID : aliased constant GUID :=
     (16#5B1B31A1#, 16#9562#, 16#11D2#, 16#3B7269C9A0003F8E#);
   Simple_FS_GUID : aliased constant GUID :=
     (16#964E5B22#, 16#6459#, 16#11D2#, 16#3B7269C9A000398E#);
   File_Info_GUID : aliased constant GUID :=
     (16#09576E92#, 16#6D3F#, 16#11D2#, 16#3B7269C9A000398E#);
   GOP_GUID : aliased constant GUID :=
     (16#9042A9DE#, 16#23DC#, 16#4A38#, 16#6A5180D0DE7AFB96#);
   type Char16_Array is array (Natural range <>) of aliased U16;
   type Key is record
      Scan_Code, Unicode : U16;
   end record with Convention => C, Size => 32;
   System_Table, Boot_Services, Image_Handle : U64 := 0;
   procedure Configure (Image, Table : U64);
   procedure Text (Value : String);
   function Read_Key (Value : out Key) return EFI_Status;
   procedure Stall (Microseconds : U64);
   function Allocate_Pages (Count : U64; Base : out U64;
                             Executable : Boolean := False) return EFI_Status;
   function Allocate_Pool (Size : U64; Base : out U64) return EFI_Status;
   function Free_Pool (Base : U64) return EFI_Status;
   function Handle_Protocol (Handle : U64; Id : access constant GUID;
                             Interface_Address : out U64) return EFI_Status;
   function Locate_Protocol (Id : access constant GUID; Interface_Address : out U64)
                             return EFI_Status;
   function Memory_Map (Size : in out U64; Buffer : U64; Map_Key : out U64;
                        Descriptor_Size : out U64; Version : out U32)
                        return EFI_Status;
   function Exit_Boot_Services (Map_Key : U64) return EFI_Status;
end AxiomOS.Firmware.UEFI;
