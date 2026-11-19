with Ada.Unchecked_Conversion;
with AxiomOS.Raw;
package body AxiomOS.Firmware.UEFI is
   use type U64;
   procedure Configure (Image, Table : U64) is
   begin
      Image_Handle := Image;
      System_Table := Table;
      Boot_Services := Raw.Load64 (Table + 96);
   end Configure;
   procedure Text (Value : String) is
      type Fn is access function (This, Text : U64) return EFI_Status
        with Convention => C;
      function Convert is new Ada.Unchecked_Conversion (U64, Fn);
      Console : constant U64 := Raw.Load64 (System_Table + 64);
      Buffer : aliased Char16_Array (0 .. 127) := (others => 0);
      Used : Natural := 0;
      S : EFI_Status;
   begin
      for C of Value loop
         Buffer (Used) := Character'Pos (C);
         Used := Used + 1;
         if Used = 127 then
            Buffer (Used) := 0;
            S := Convert (Raw.Load64 (Console + 8))
              (Console, Raw.Number (Buffer'Address));
            Used := 0;
         end if;
      end loop;
      Buffer (Used) := 0;
      S := Convert (Raw.Load64 (Console + 8))
        (Console, Raw.Number (Buffer'Address));
   end Text;
   function Read_Key (Value : out Key) return EFI_Status is
      type Fn is access function (This : U64; Value : out Key) return EFI_Status
        with Convention => C;
      function Convert is new Ada.Unchecked_Conversion (U64, Fn);
      Console : constant U64 := Raw.Load64 (System_Table + 48);
   begin return Convert (Raw.Load64 (Console + 8)) (Console, Value); end Read_Key;
   procedure Stall (Microseconds : U64) is
      type Fn is access function (Time : U64) return EFI_Status with Convention => C;
      function Convert is new Ada.Unchecked_Conversion (U64, Fn);
      S : EFI_Status;
   begin S := Convert (Raw.Load64 (Boot_Services + 248)) (Microseconds); end Stall;
   function Allocate_Pages (Count : U64; Base : out U64;
                             Executable : Boolean := False) return EFI_Status is
      type Fn is access function (Kind, Mem_Type : U32; Count : U64;
                                  Base : out U64) return EFI_Status
        with Convention => C;
      function Convert is new Ada.Unchecked_Conversion (U64, Fn);
   begin
      Base := 0;
      return Convert (Raw.Load64 (Boot_Services + 40))
        (0, (if Executable then 1 else 2), Count, Base);
   end Allocate_Pages;
   function Allocate_Pool (Size : U64; Base : out U64) return EFI_Status is
      type Fn is access function (Mem_Type : U32; Size : U64;
                                  Base : out U64) return EFI_Status
        with Convention => C;
      function Convert is new Ada.Unchecked_Conversion (U64, Fn);
   begin return Convert (Raw.Load64 (Boot_Services + 64)) (2, Size, Base); end Allocate_Pool;
   function Free_Pool (Base : U64) return EFI_Status is
      type Fn is access function (Base : U64) return EFI_Status with Convention => C;
      function Convert is new Ada.Unchecked_Conversion (U64, Fn);
   begin return Convert (Raw.Load64 (Boot_Services + 72)) (Base); end Free_Pool;
   function Handle_Protocol (Handle : U64; Id : access constant GUID;
                             Interface_Address : out U64) return EFI_Status is
      type Fn is access function (Handle : U64; Id : access constant GUID;
                                  Interface_Address : out U64) return EFI_Status
        with Convention => C;
      function Convert is new Ada.Unchecked_Conversion (U64, Fn);
   begin return Convert (Raw.Load64 (Boot_Services + 152))
       (Handle, Id, Interface_Address); end Handle_Protocol;
   function Locate_Protocol (Id : access constant GUID; Interface_Address : out U64)
                             return EFI_Status is
      type Fn is access function (Id : access constant GUID; Registration : U64;
                                  Interface_Address : out U64) return EFI_Status
        with Convention => C;
      function Convert is new Ada.Unchecked_Conversion (U64, Fn);
   begin return Convert (Raw.Load64 (Boot_Services + 320))
       (Id, 0, Interface_Address); end Locate_Protocol;
   function Memory_Map (Size : in out U64; Buffer : U64; Map_Key : out U64;
                        Descriptor_Size : out U64; Version : out U32)
                        return EFI_Status is
      type Fn is access function (Size : in out U64; Buffer : U64;
                                  Map_Key : out U64; Descriptor_Size : out U64;
                                  Version : out U32) return EFI_Status
        with Convention => C;
      function Convert is new Ada.Unchecked_Conversion (U64, Fn);
   begin return Convert (Raw.Load64 (Boot_Services + 56))
       (Size, Buffer, Map_Key, Descriptor_Size, Version); end Memory_Map;
   function Exit_Boot_Services (Map_Key : U64) return EFI_Status is
      type Fn is access function (Image, Map_Key : U64) return EFI_Status
        with Convention => C;
      function Convert is new Ada.Unchecked_Conversion (U64, Fn);
   begin return Convert (Raw.Load64 (Boot_Services + 232))
       (Image_Handle, Map_Key); end Exit_Boot_Services;
end AxiomOS.Firmware.UEFI;
