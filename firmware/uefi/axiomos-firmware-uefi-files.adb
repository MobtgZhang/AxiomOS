with Ada.Unchecked_Conversion;
with AxiomOS.Raw;
package body AxiomOS.Firmware.UEFI.Files is
   use type U64;
   procedure Load (Path : String; Base, Length : out U64; Result : out Status) is
      type Open_Volume_Fn is access function (This : U64; Root : out U64)
        return EFI_Status with Convention => C;
      type Open_Fn is access function (This : U64; File : out U64; Name, Mode,
                                       Attributes : U64) return EFI_Status
        with Convention => C;
      type Info_Fn is access function (This : U64; Id : access constant GUID;
                                       Size : in out U64; Buffer : U64)
        return EFI_Status with Convention => C;
      type Read_Fn is access function (This : U64; Size : in out U64; Buffer : U64)
        return EFI_Status with Convention => C;
      type Close_Fn is access function (This : U64) return EFI_Status
        with Convention => C;
      function To_Volume is new Ada.Unchecked_Conversion (U64, Open_Volume_Fn);
      function To_Open is new Ada.Unchecked_Conversion (U64, Open_Fn);
      function To_Info is new Ada.Unchecked_Conversion (U64, Info_Fn);
      function To_Read is new Ada.Unchecked_Conversion (U64, Read_Fn);
      function To_Close is new Ada.Unchecked_Conversion (U64, Close_Fn);
      Loaded, Device, FS, Root, File : U64 := 0;
      Info : aliased Bytes (0 .. 1023) := (others => 0);
      Name : aliased Char16_Array (0 .. 255) := (others => 0);
      Size : U64 := Info'Length;
      S, Ignored : EFI_Status;
   begin
      Base := 0;
      Length := 0;
      Result := IO_Error;
      if Path'Length > 255 then Result := Invalid_Argument; return; end if;
      S := Handle_Protocol (Image_Handle, Loaded_Image_GUID'Access, Loaded);
      if S /= 0 then return; end if;
      Device := Raw.Load64 (Loaded + 24);
      S := Handle_Protocol (Device, Simple_FS_GUID'Access, FS);
      if S /= 0 then return; end if;
      S := To_Volume (Raw.Load64 (FS + 8)) (FS, Root);
      if S /= 0 then return; end if;
      for I in Path'Range loop Name (I - Path'First) := Character'Pos (Path (I)); end loop;
      S := To_Open (Raw.Load64 (Root + 8))
        (Root, File, Raw.Number (Name'Address), 1, 0);
      if S /= 0 then
         Ignored := To_Close (Raw.Load64 (Root + 16)) (Root);
         Result := Not_Found;
         return;
      end if;
      S := To_Info (Raw.Load64 (File + 64))
        (File, File_Info_GUID'Access, Size, Raw.Number (Info'Address));
      if S = 0 then
         Length := Raw.Load64 (Raw.Number (Info'Address) + 8);
         if Length = 0 or else Length > 8 * 1024 * 1024 then
            Result := No_Space;
         else
            S := Allocate_Pool (Length, Base);
            if S = 0 then
               Size := Length;
               S := To_Read (Raw.Load64 (File + 32)) (File, Size, Base);
               if S = 0 and Size = Length then
                  Result := Success;
               else
                  Ignored := Free_Pool (Base);
                  Base := 0;
               end if;
            else Result := Out_Of_Memory;
            end if;
         end if;
      end if;
      Ignored := To_Close (Raw.Load64 (File + 16)) (File);
      Ignored := To_Close (Raw.Load64 (Root + 16)) (Root);
   end Load;
end AxiomOS.Firmware.UEFI.Files;
