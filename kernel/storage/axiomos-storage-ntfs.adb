with Interfaces;
with AxiomOS.Storage.Endian; use AxiomOS.Storage.Endian;
package body AxiomOS.Storage.NTFS is
   use type U8, U64;
   Index_Name : constant String := "$I30";
   subtype Record_Data is Bytes (0 .. 4095);
   procedure Fixup (Data : in out Bytes; Signature : String; Result : out Status) is
      P, N : Natural;
      USN : U64;
   begin
      Result := Corrupt;
      if Data'First /= 0 or else Data'Length < 512 or else Data'Length mod 512 /= 0 or else
        not Text (Data, 0, Signature) then return; end if;
      P := Natural (LE (Data, 4, 2)); N := Natural (LE (Data, 6, 2));
      if N /= Data'Length / 512 + 1 or else P < 8 or else P > Data'Length or else
        N * 2 > Data'Length - P then return; end if;
      USN := LE (Data, P, 2);
      for I in 1 .. N - 1 loop
         if LE (Data, I * 512 - 2, 2) /= USN then return; end if;
         Data (I * 512 - 2) := Data (P + I * 2);
         Data (I * 512 - 1) := Data (P + I * 2 + 1);
      end loop;
      Result := Success;
   end Fixup;
   procedure Attribute (Data : Record_Data; Kind : U64; Named : Boolean;
                        Pos : out Natural; Result : out Status) is
      Cursor, Used, Length, N, Name_Pos : Natural;
      Found : Boolean;
   begin
      Pos := 0; Result := Corrupt;
      Used := Natural (LE (Data, 24, 4)); Cursor := Natural (LE (Data, 20, 2));
      if Used > Data'Length or else Cursor < 24 or else Cursor > Used then return; end if;
      while Cursor <= Used and then Used - Cursor >= 4 loop
         if LE (Data, Cursor, 4) = 16#FFFF_FFFF# then Result := Not_Found; return; end if;
         if Used - Cursor < 24 then return; end if;
         Length := Natural (LE (Data, Cursor + 4, 4));
         if Length < 24 or else Length mod 8 /= 0 or else Length > Used - Cursor then return; end if;
         N := Natural (Data (Cursor + 9)); Name_Pos := Natural (LE (Data, Cursor + 10, 2));
         if N > 0 and then (Name_Pos < 16 or else Name_Pos > Length or else N * 2 > Length - Name_Pos) then return; end if;
         Found := (N = 0 and not Named);
         if Named and N = 4 then
            Found := True;
            for I in 0 .. 3 loop
               if LE (Data, Cursor + Name_Pos + I * 2, 2) /= Character'Pos (Index_Name (I + 1)) then Found := False; end if;
            end loop;
         end if;
         if LE (Data, Cursor, 4) = Kind and Found then
            if Data (Cursor + 8) > 1 or else (Data (Cursor + 8) = 1 and Length < 64) then return; end if;
            if (LE (Data, Cursor + 12, 2) and not U64 (16#8000#)) /= 0 then Result := Unsupported; return; end if;
            Pos := Cursor; Result := Success; return;
         end if;
         Cursor := Cursor + Length;
      end loop;
   end Attribute;
   procedure Stream (V : Volume; Data : Record_Data; Pos : Natural; Offset : U64;
                     Buffer : out Bytes; Count : out Natural; Result : out Status) is
      Attr_Length : constant Natural := Natural (LE (Data, Pos + 4, 4));
      Length, Cursor, Logical, LCN, Run_Length, Displacement, At_Byte, Run_Bytes, Part : U64 := 0;
      Run_Pos, Width, Sign_Width, Header, Goal : Natural;
   begin
      Buffer := (others => 0); Count := 0; Result := Corrupt;
      if Data (Pos + 8) = 0 then
         Length := LE (Data, Pos + 16, 4); Cursor := LE (Data, Pos + 20, 2);
         if Cursor < 24 or else Cursor > U64 (Attr_Length) or else Length > U64 (Attr_Length) - Cursor then return; end if;
         Result := Success;
         if Offset >= Length then return; end if;
         Count := Natural (U64' Min (U64 (Buffer'Length), Length - Offset));
         for I in 0 .. Integer (Count) - 1 loop Buffer (Buffer'First + I) := Data (Pos + Natural (Cursor + Offset) + I); end loop;
         return;
      elsif Data (Pos + 8) /= 1 or else Attr_Length < 64 then return; end if;
      if LE (Data, Pos + 16, 8) /= 0 then Result := Unsupported; return; end if;
      Length := LE (Data, Pos + 48, 8);
      if Offset >= Length or Buffer'Length = 0 then Result := Success; return; end if;
      -- Uninitialized NTFS data reads as zero, even if allocation contains old bytes.
      Goal := Natural (U64'Min (U64 (Buffer'Length), Length - Offset));
      if Offset >= LE (Data, Pos + 56, 8) then Count := Goal; Result := Success; return; end if;
      Goal := Natural (U64'Min (U64 (Goal), LE (Data, Pos + 56, 8) - Offset));
      Run_Pos := Natural (LE (Data, Pos + 32, 2));
      if Run_Pos < 64 or else Run_Pos >= Attr_Length then return; end if;
      while Run_Pos < Attr_Length loop
         Header := Natural (Data (Pos + Run_Pos));
         exit when Header = 0;
         Width := Header mod 16; Sign_Width := Header / 16;
         if Width = 0 or else Width > 8 or else Sign_Width > 8 or else
           Width + Sign_Width >= Attr_Length - Run_Pos then return; end if;
         Run_Length := LE (Data, Pos + Run_Pos + 1, Width);
         if Run_Length = 0 or else Run_Length > V.Blocks or else Run_Length > U64'Last / V.Block_Size then return; end if;
         Displacement := LE (Data, Pos + Run_Pos + 1 + Width, Sign_Width);
         if Sign_Width > 0 then
            if (Data (Pos + Run_Pos + Width + Sign_Width) and 128) /= 0 then
               if Sign_Width < 8 then Displacement := Displacement or (U64'Last - (Interfaces.Shift_Left (U64 (1), 8 * Sign_Width) - 1)); end if;
               Displacement := 0 - Displacement;
               if Displacement > LCN then return; end if;
               LCN := LCN - Displacement;
            else
               if Displacement > V.Blocks or else LCN > V.Blocks - Displacement then return; end if;
               LCN := LCN + Displacement;
            end if;
            if LCN >= V.Blocks or else Run_Length > V.Blocks - LCN then return; end if;
         end if;
         Run_Bytes := Run_Length * V.Block_Size;
         if Logical > U64'Last - Run_Bytes then return; end if;
         Cursor := Offset + U64 (Count);
         if Cursor >= Logical and then Cursor - Logical < Run_Bytes then
            At_Byte := Cursor - Logical;
            Part := U64'Min (U64 (Goal - Count), Run_Bytes - At_Byte);
            if Sign_Width /= 0 then
               Storage.Read (V.Disk, LCN * V.Block_Size + At_Byte,
                 Buffer (Buffer'First + Count .. Buffer'First + Count + Natural (Part) - 1), Result);
               if Result /= Success then return; end if;
            end if;
            Count := Count + Natural (Part);
            if Count = Goal then
               Count := Natural (U64'Min (U64 (Buffer'Length), Length - Offset)); Result := Success; return;
            end if;
         end if;
         Logical := Logical + Run_Bytes; Run_Pos := Run_Pos + 1 + Width + Sign_Width;
      end loop;
      Result := Corrupt;
   end Stream;
   procedure Record_Read (V : Volume; Id : U64; Data : out Record_Data; Result : out Status) is
      Master : Record_Data := (others => 0);
      Pos, Count : Natural;
   begin
      Data := (others => 0);
      Storage.Read (V.Disk, V.MFT * V.Block_Size, Master (0 .. Natural (V.Record_Size) - 1), Result);
      if Result /= Success then return; end if;
      Fixup (Master (0 .. Natural (V.Record_Size) - 1), "FILE", Result);
      if Result /= Success then return; end if;
      if Id = 0 then Data := Master; return; end if;
      Attribute (Master, 16#80#, False, Pos, Result);
      if Result /= Success then return; end if;
      if Id > U64'Last / V.Record_Size then Result := Corrupt; return; end if;
      Stream (V, Master, Pos, Id * V.Record_Size, Data (0 .. Natural (V.Record_Size) - 1), Count, Result);
      if Result /= Success then return; end if;
      if Count /= Natural (V.Record_Size) then Result := Corrupt; return; end if;
      Fixup (Data (0 .. Natural (V.Record_Size) - 1), "FILE", Result);
      if Result /= Success then return; end if;
      if (LE (Data, 22, 2) and 1) = 0 then Result := Not_Found; return; end if;
      Attribute (Data, 16#20#, False, Pos, Result);
      if Result = Success then Result := Unsupported;
      elsif Result = Not_Found then Result := Success; end if;
   end Record_Read;
   procedure Object (V : Volume; Id : U64; Item : out File_Object; Result : out Status) is
      Data : Record_Data;
      Pos : Natural;
   begin
      Item := (others => <>);
      Record_Read (V, Id, Data, Result);
      if Result /= Success then return; end if;
      Item := (Id, 0, (LE (Data, 22, 2) and 2) /= 0);
      if not Item.Directory then
         Attribute (Data, 16#80#, False, Pos, Result);
         if Result /= Success then return; end if;
         Item.Length := (if Data (Pos + 8) = 0 then LE (Data, Pos + 16, 4) else LE (Data, Pos + 48, 8));
      end if;
   end Object;
   procedure Mount (V : in out Volume; Result : out Status) is
      Boot : Bytes (0 .. 511);
      Data : Record_Data;
      Pos : Natural;
      Sector, Clusters, Size : U64;
      Root_Object : File_Object;
      function Record_Bytes (Value : U8) return U64 is
      begin
         if Value >= 244 then return Interfaces.Shift_Left (U64 (1), Natural (256 - U64 (Value)));
         elsif Value in 1 .. 128 then return U64 (Value) * V.Block_Size;
         else return 0; end if;
      end Record_Bytes;
   begin
      V.Kind := Unknown;
      Storage.Read (V.Disk, 0, Boot, Result);
      if Result /= Success then return; end if;
      Result := Corrupt;
      if not Text (Boot, 3, "NTFS    ") or else LE (Boot, 510, 2) /= 16#AA55# then return; end if;
      Sector := LE (Boot, 11, 2); Clusters := LE (Boot, 13, 1);
      if Sector /= 512 then Result := Unsupported; return; end if;
      if not Power_Of_Two (Clusters) or else Clusters > 128 then return; end if;
      V.Block_Size := Sector * Clusters; Size := LE (Boot, 40, 8);
      if Size = 0 or else Size > V.Disk.Length / Sector then return; end if;
      V.Blocks := Size / Clusters; V.MFT := LE (Boot, 48, 8);
      V.Record_Size := Record_Bytes (Boot (64)); V.Index_Size := Record_Bytes (Boot (68));
      if V.MFT >= V.Blocks or else V.Record_Size < 512 or else V.Record_Size > 4096 or else
        not Power_Of_Two (V.Record_Size) or else V.Index_Size < 512 or else V.Index_Size > 4096 or else
        not Power_Of_Two (V.Index_Size) then Result := Unsupported; return; end if;
      Record_Read (V, 3, Data, Result);
      if Result /= Success then return; end if;
      Attribute (Data, 16#70#, False, Pos, Result);
      if Result /= Success then return; end if;
      declare Info : Bytes (0 .. 11); Count : Natural;
      begin
         Stream (V, Data, Pos, 0, Info, Count, Result);
         if Result /= Success then return; end if;
         if Count /= 12 or else (LE (Info, 10, 2) and 1) /= 0 then Result := Corrupt; return; end if;
      end;
      Object (V, 5, Root_Object, Result);
      V.Root := Root_Object;
      if Result = Success and V.Root.Directory then V.Kind := NTFS_Volume;
      elsif Result = Success then Result := Corrupt; end if;
   end Mount;
   procedure Read_File (V : Volume; Item : File_Object; Offset : U64;
                        Buffer : out Bytes; Count : out Natural; Result : out Status) is
      Data : Record_Data;
      Pos : Natural;
   begin
      Buffer := (others => 0); Count := 0;
      Record_Read (V, Item.Id, Data, Result);
      if Result /= Success then return; end if;
      Attribute (Data, 16#80#, False, Pos, Result);
      if Result = Success then Stream (V, Data, Pos, Offset, Buffer, Count, Result); end if;
   end Read_File;
   procedure Child (V : Volume; Parent : File_Object; Name : String;
                    Item : out File_Object; Result : out Status) is
      Data, Root_Data, Index : Record_Data;
      Bitmap : Bytes (0 .. 255);
      Pos, Alloc_Pos, Bitmap_Pos, Count : Natural;
      Offset, Allocation_Length : U64;
      Found : Boolean := False;
      procedure Scan (B : Bytes; Header : Natural) is
         Cursor, Finish, Length, Key_Size, Flags, Name_Length : Natural;
         Candidate : String (1 .. 255);
      begin
         Result := Corrupt;
         if Header > B'Length or else B'Length - Header < 16 then return; end if;
         Cursor := Natural (LE (B, Header, 4)); Finish := Natural (LE (B, Header + 4, 4));
         if Cursor < 16 or else Finish < Cursor or else Finish > B'Length - Header then return; end if;
         Cursor := Cursor + Header; Finish := Finish + Header;
         while Cursor <= Finish and then Finish - Cursor >= 16 loop
            Length := Natural (LE (B, Cursor + 8, 2)); Key_Size := Natural (LE (B, Cursor + 10, 2));
            Flags := Natural (LE (B, Cursor + 12, 2));
            if Length < 16 or else Length mod 8 /= 0 or else Length > Finish - Cursor or else Key_Size > Length - 16 then return; end if;
            if (Flags mod 4) >= 2 then Result := Not_Found; return; end if;
            if Key_Size < 66 then return; end if;
            Name_Length := Natural (B (Cursor + 80));
            if Name_Length * 2 > Key_Size - 66 then return; end if;
            if Name_Length = Name'Length then
               for I in 0 .. Name_Length - 1 loop
                  declare C : constant U64 := LE (B, Cursor + 82 + I * 2, 2);
                  begin Candidate (I + 1) := (if C < 128 then Character'Val (C) else Character'Val (0)); end;
               end loop;
               if Equal_Name (Candidate (1 .. Name_Length), Name) then
                  Object (V, LE (B, Cursor, 8) and 16#0000_FFFF_FFFF_FFFF#, Item, Result);
                  Found := Result = Success; return;
               end if;
            end if;
            Cursor := Cursor + Length;
         end loop;
      end Scan;
   begin
      Item := (others => <>); Result := Invalid_Argument;
      if not Parent.Directory or Name'Length = 0 or Name'Length > 255 then return; end if;
      Record_Read (V, Parent.Id, Data, Result);
      if Result /= Success then return; end if;
      Attribute (Data, 16#90#, True, Pos, Result);
      if Result /= Success then return; end if;
      Stream (V, Data, Pos, 0, Root_Data, Count, Result);
      if Result /= Success then return; end if;
      if Count < 32 then Result := Corrupt; return; end if;
      Scan (Root_Data (0 .. Count - 1), 16);
      if Found or Result /= Not_Found then return; end if;
      Attribute (Data, 16#A0#, True, Alloc_Pos, Result);
      if Result = Not_Found then return; elsif Result /= Success then return; end if;
      if Data (Alloc_Pos + 8) /= 1 then Result := Corrupt; return; end if;
      Allocation_Length := LE (Data, Alloc_Pos + 48, 8);
      if Allocation_Length > 8 * 1024 * 1024 or else Allocation_Length mod V.Index_Size /= 0 then Result := Unsupported; return; end if;
      Attribute (Data, 16#B0#, True, Bitmap_Pos, Result);
      if Result /= Success then return; end if;
      Stream (V, Data, Bitmap_Pos, 0, Bitmap, Count, Result);
      if Result /= Success then return; end if;
      Offset := 0;
      while Offset < Allocation_Length loop
         declare Bit : constant Natural := Natural (Offset / V.Index_Size);
         begin
            if Bit / 8 >= Count then Result := Corrupt; return; end if;
            if (Bitmap (Bit / 8) and Interfaces.Shift_Left (U8 (1), Bit mod 8)) /= 0 then
               declare Actual : Natural;
               begin
                  Stream (V, Data, Alloc_Pos, Offset, Index (0 .. Natural (V.Index_Size) - 1), Actual, Result);
                  if Result /= Success then return; end if;
                  if Actual /= Natural (V.Index_Size) then Result := Corrupt; return; end if;
                  Fixup (Index (0 .. Actual - 1), "INDX", Result);
                  if Result /= Success then return; end if;
                  Scan (Index (0 .. Actual - 1), 24);
                  if Found or Result /= Not_Found then return; end if;
               end;
            end if;
         end;
         Offset := Offset + V.Index_Size;
      end loop;
      Result := Not_Found;
   end Child;
end AxiomOS.Storage.NTFS;
