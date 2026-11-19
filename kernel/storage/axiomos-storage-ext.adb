with Interfaces;
with AxiomOS.Storage.Checksums;
with AxiomOS.Storage.Endian; use AxiomOS.Storage.Endian;
package body AxiomOS.Storage.Ext is
   use type U8, U32, U64;
   subtype Inode_Data is Bytes (0 .. 255);
   procedure Inode (V : Volume; Id : U64; Data : out Inode_Data; Result : out Status) is
      Desc : Bytes (0 .. 63);
      Group, Table, Index, Expected : U64;
      Full_Inode : Bytes (0 .. 4095);
      C : U32;
      Number : Bytes (0 .. 3);
   begin
      Data := (others => 0); Result := Corrupt;
      if Id = 0 or else Id > V.Inodes then return; end if;
      Group := (Id - 1) / V.Inodes_Per_Group;
      Index := (Id - 1) mod V.Inodes_Per_Group;
      Storage.Read (V.Disk, V.Descriptors + Group * V.Descriptor_Size,
                    Desc (0 .. Natural (V.Descriptor_Size) - 1), Result);
      if Result /= Success then return; end if;
      if V.Metadata_Checksum then
         for I in 0 .. 3 loop Number (I) := U8 ((Group / Interfaces.Shift_Left (U64 (1), 8 * I)) mod 256); end loop;
         C := Checksums.CRC32C (Number, V.Checksum_Seed);
         Expected := LE (Desc, 30, 2); Desc (30 .. 31) := (others => 0);
         C := Checksums.CRC32C (Desc (0 .. Natural (V.Descriptor_Size) - 1), C);
         if U64 (C and 16#FFFF#) /= Expected then Result := Corrupt; return; end if;
      end if;
      Table := LE (Desc, 8, 4);
      if V.Descriptor_Size = 64 then Table := Table + LE (Desc, 40, 4) * 2 ** 32; end if;
      if Table = 0 or else Table >= V.Blocks then Result := Corrupt; return; end if;
      Storage.Read (V.Disk, Table * V.Block_Size + Index * V.Inode_Size,
                    Full_Inode (0 .. Natural (V.Inode_Size) - 1), Result);
      if Result /= Success then return; end if;
      if V.Metadata_Checksum then
         for I in 0 .. 3 loop Number (I) := U8 ((Id / Interfaces.Shift_Left (U64 (1), 8 * I)) mod 256); end loop;
         C := Checksums.CRC32C (Number, V.Checksum_Seed);
         C := Checksums.CRC32C (Full_Inode (100 .. 103), C);
         Expected := LE (Full_Inode, 124, 2); Full_Inode (124 .. 125) := (others => 0);
         if V.Inode_Size > 128 and then LE (Full_Inode, 128, 2) >= 4 then
            Expected := Expected + LE (Full_Inode, 130, 2) * 65536;
            Full_Inode (130 .. 131) := (others => 0);
         end if;
         C := Checksums.CRC32C (Full_Inode (0 .. Natural (V.Inode_Size) - 1), C);
         if (V.Inode_Size > 128 and then LE (Full_Inode, 128, 2) >= 4 and then U64 (C) /= Expected) or else
           ((V.Inode_Size = 128 or else LE (Full_Inode, 128, 2) < 4) and then U64 (C and 16#FFFF#) /= Expected)
         then Result := Corrupt; return; end if;
      end if;
      Data (0 .. Natural (U64'Min (V.Inode_Size, 256)) - 1) :=
        Full_Inode (0 .. Natural (U64'Min (V.Inode_Size, 256)) - 1);
   end Inode;
   procedure Object (V : Volume; Id : U64; Item : out File_Object; Result : out Status) is
      Data : Inode_Data;
      Mode : U64;
   begin
      Item := (others => <>);
      Inode (V, Id, Data, Result);
      if Result /= Success then return; end if;
      Mode := LE (Data, 0, 2) and 16#F000#;
      if Mode /= 16#4000# and Mode /= 16#8000# then Result := Unsupported; return; end if;
      Item := (Id, LE (Data, 4, 4), Mode = 16#4000#);
      if Mode = 16#8000# then Item.Length := Item.Length + LE (Data, 108, 4) * 2 ** 32; end if;
   end Object;
   procedure Mount (V : in out Volume; Result : out Status) is
      Super : Bytes (0 .. 1023);
      Incompat, Compat, RO, Log : U64;
      Root_Object : File_Object;
   begin
      V.Kind := Unknown;
      Storage.Read (V.Disk, 1024, Super, Result);
      if Result /= Success then return; end if;
      Result := Corrupt;
      if LE (Super, 56, 2) /= 16#EF53# then return; end if;
      Log := LE (Super, 24, 4);
      if Log > 2 then Result := Unsupported; return; end if;
      V.Block_Size := 1024 * Interfaces.Shift_Left (U64 (1), Natural (Log));
      Incompat := LE (Super, 96, 4); Compat := LE (Super, 92, 4); RO := LE (Super, 100, 4);
      -- Extents, filetype, 64bit and flex_bg; recovery, encryption, inline data,
      -- bigalloc and unfamiliar layout features are rejected before traversal.
      if (Incompat and not U64 (16#22C2#)) /= 0 or else
        (RO and not U64 (16#47B#)) /= 0 then Result := Unsupported; return; end if;
      if (LE (Super, 58, 2) and 1) = 0 then Result := Corrupt; return; end if;
      V.Metadata_Checksum := (RO and 16#400#) /= 0;
      if V.Metadata_Checksum then
         if Super (373) /= 1 or else U64 (Checksums.CRC32C (Super (0 .. 1019))) /= LE (Super, 1020, 4)
         then Result := Corrupt; return; end if;
         V.Checksum_Seed := (if (Incompat and 16#2000#) /= 0 then U32 (LE (Super, 624, 4))
                            else Checksums.CRC32C (Super (104 .. 119)));
      end if;
      V.Features := Incompat; V.Blocks := LE (Super, 4, 4);
      V.Descriptor_Size := 32;
      if (Incompat and 16#80#) /= 0 then
         V.Blocks := V.Blocks + LE (Super, 336, 4) * 2 ** 32;
         V.Descriptor_Size := LE (Super, 254, 2);
         if V.Descriptor_Size /= 64 then Result := Unsupported; return; end if;
      end if;
      V.Inodes := LE (Super, 0, 4); V.Per_Group := LE (Super, 32, 4);
      V.Inodes_Per_Group := LE (Super, 40, 4);
      V.Inode_Size := (if LE (Super, 76, 4) = 0 then 128 else LE (Super, 88, 2));
      if V.Blocks = 0 or else V.Blocks > V.Disk.Length / V.Block_Size or else
        V.Inodes < 2 or else V.Per_Group = 0 or else V.Inodes_Per_Group = 0 or else
        V.Inode_Size < 128 or else V.Inode_Size > V.Block_Size or else
        V.Block_Size mod V.Inode_Size /= 0 then Result := Corrupt; return; end if;
      V.Descriptors := (if V.Block_Size = 1024 then 2048 else V.Block_Size);
      V.Kind := (if (Incompat and 16#40#) /= 0 then EXT4 elsif (Compat and 4) /= 0 then EXT3 else EXT2);
      Object (V, 2, Root_Object, Result);
      V.Root := Root_Object;
      if Result = Success and then not V.Root.Directory then Result := Corrupt; end if;
      if Result /= Success then V.Kind := Unknown; end if;
   end Mount;
   procedure Block (V : Volume; Data : Inode_Data; Id, Logical : U64;
                    Physical : out U64; Result : out Status) is
      Tree : Bytes (0 .. 4095) := (others => 0);
      Entries, Depth, Maximum, Previous, Key, Child_Block, N, Span, Index, Ptr : U64;
      Pos : Natural;
      Word : Bytes (0 .. 3);
      C : U32;
      Check_Pos : Natural;
   begin
      Physical := 0; Result := Corrupt;
      if (LE (Data, 32, 4) and 16#80000#) /= 0 then
         Tree (0 .. 59) := Data (40 .. 99); Maximum := 60; Previous := 6;
         for Level in 0 .. 5 loop
            if LE (Tree, 0, 2) /= 16#F30A# then return; end if;
            Entries := LE (Tree, 2, 2); Depth := LE (Tree, 6, 2);
            if Depth >= Previous or else Depth > 5 or else Entries > (Maximum - 12) / 12 or else
              LE (Tree, 4, 2) > (Maximum - 12) / 12 or else Entries > LE (Tree, 4, 2) then return; end if;
            Child_Block := 0; Previous := Depth;
            for I in 0 .. Integer (Entries) - 1 loop
               Pos := 12 + I * 12; Key := LE (Tree, Pos, 4);
               if Depth = 0 then
                  N := LE (Tree, Pos + 4, 2);
                  Span := (if N > 32768 then N - 32768 else N);
                  if Span = 0 then return; end if;
                  if Logical >= Key and then Logical - Key < Span then
                     if N > 32768 then Result := Success; return; end if;
                     Physical := LE (Tree, Pos + 8, 4) + LE (Tree, Pos + 6, 2) * 2 ** 32 + Logical - Key;
                     if Physical >= V.Blocks or else Physical = 0 then return; end if;
                     Result := Success; return;
                  end if;
               elsif Key <= Logical then
                  Child_Block := LE (Tree, Pos + 4, 4) + LE (Tree, Pos + 8, 2) * 2 ** 32;
               end if;
            end loop;
            if Depth = 0 or Child_Block = 0 then Result := Success; return; end if;
            if Child_Block >= V.Blocks then return; end if;
            Storage.Read (V.Disk, Child_Block * V.Block_Size, Tree (0 .. Natural (V.Block_Size) - 1), Result);
            if Result /= Success then return; end if;
            Result := Corrupt; Maximum := V.Block_Size;
            if V.Metadata_Checksum then
               for I in 0 .. 3 loop Word (I) := U8 ((Id / Interfaces.Shift_Left (U64 (1), 8 * I)) mod 256); end loop;
               C := Checksums.CRC32C (Word, V.Checksum_Seed);
               C := Checksums.CRC32C (Data (100 .. 103), C);
               Check_Pos := 12 + Natural (LE (Tree, 4, 2)) * 12;
               if Check_Pos > Natural (V.Block_Size) - 4 then return; end if;
               C := Checksums.CRC32C (Tree (0 .. Check_Pos - 1), C);
               if U64 (C) /= LE (Tree, Check_Pos, 4) then return; end if;
            end if;
         end loop;
      else
         if Logical < 12 then Physical := LE (Data, 40 + Natural (Logical) * 4, 4);
         else
            N := V.Block_Size / 4; Index := Logical - 12; Span := N;
            for Level in 1 .. 3 loop
               if Index < Span then
                  Ptr := LE (Data, 84 + Level * 4, 4);
                  for D in reverse 1 .. Level loop
                     if Ptr = 0 then Physical := 0; Result := Success; return; end if;
                     if Ptr >= V.Blocks then return; end if;
                     Span := 1;
                     for J in 1 .. D - 1 loop Span := Span * N; end loop;
                     Storage.Read (V.Disk, Ptr * V.Block_Size + (Index / Span) * 4, Word, Result);
                     if Result /= Success then return; end if;
                     Ptr := LE (Word, 0, 4); Index := Index mod Span;
                  end loop;
                  Physical := Ptr; exit;
               end if;
               Index := Index - Span; Span := Span * N;
               if Level = 3 then Result := Unsupported; return; end if;
            end loop;
         end if;
         if Physical >= V.Blocks then Result := Corrupt; return; end if;
         Result := Success;
      end if;
   end Block;
   procedure Read_File (V : Volume; Item : File_Object; Offset : U64;
                        Buffer : out Bytes; Count : out Natural; Result : out Status) is
      Data : Inode_Data;
      P, Cursor : U64 := Offset;
      Amount, Goal : Natural;
      Whole : Bytes (0 .. 4095);
      C : U32;
      Number : Bytes (0 .. 3);
   begin
      Count := 0; Buffer := (others => 0); Result := Success;
      if Offset >= Item.Length or Buffer'Length = 0 then return; end if;
      Goal := Natural (U64'Min (U64 (Buffer'Length), Item.Length - Offset));
      Inode (V, Item.Id, Data, Result);
      if Result /= Success then return; end if;
      if Item.Directory and then (LE (Data, 32, 4) and 16#1000#) /= 0 then
         Result := Unsupported; return;
      end if;
      while Count < Goal loop
         Block (V, Data, Item.Id, Cursor / V.Block_Size, P, Result);
         if Result /= Success then return; end if;
         Amount := Natural'Min (Goal - Count, Natural (V.Block_Size - Cursor mod V.Block_Size));
         if P /= 0 then
            if Item.Directory and V.Metadata_Checksum then
               Storage.Read (V.Disk, P * V.Block_Size, Whole (0 .. Natural (V.Block_Size) - 1), Result);
               if Result /= Success then return; end if;
               declare Tail : constant Natural := Natural (V.Block_Size) - 12;
               begin
                  if LE (Whole, Tail, 4) /= 0 or else LE (Whole, Tail + 4, 2) /= 12 or else
                    LE (Whole, Tail + 6, 2) /= 16#DE00# then Result := Corrupt; return; end if;
                  for I in 0 .. 3 loop Number (I) := U8 ((Item.Id / Interfaces.Shift_Left (U64 (1), 8 * I)) mod 256); end loop;
                  C := Checksums.CRC32C (Number, V.Checksum_Seed);
                  C := Checksums.CRC32C (Data (100 .. 103), C);
                  C := Checksums.CRC32C (Whole (0 .. Tail - 1), C);
                  if U64 (C) /= LE (Whole, Tail + 8, 4) then Result := Corrupt; return; end if;
               end;
               Buffer (Buffer'First + Count .. Buffer'First + Count + Amount - 1) :=
                 Whole (Natural (Cursor mod V.Block_Size) .. Natural (Cursor mod V.Block_Size) + Amount - 1);
            else
               Storage.Read (V.Disk, P * V.Block_Size + Cursor mod V.Block_Size,
                 Buffer (Buffer'First + Count .. Buffer'First + Count + Amount - 1), Result);
               if Result /= Success then return; end if;
            end if;
         elsif Item.Directory then Result := Corrupt; return;
         end if;
         Count := Count + Amount; Cursor := Cursor + U64 (Amount);
      end loop;
   end Read_File;
   procedure Child (V : Volume; Parent : File_Object; Name : String;
                    Item : out File_Object; Result : out Status) is
      Header : Bytes (0 .. 7); Text : Bytes (0 .. 254);
      Offset : U64 := 0;
      Id, Length, Name_Length : U64;
      Count : Natural;
   begin
      Item := (others => <>); Result := Invalid_Argument;
      if not Parent.Directory or Name'Length = 0 or Name'Length > 255 then return; end if;
      if Parent.Length > 64 * 1024 * 1024 then Result := Unsupported; return; end if;
      while Offset < Parent.Length loop
         Read_File (V, Parent, Offset, Header, Count, Result);
         if Result /= Success then return; end if;
         if Count /= 8 then Result := Corrupt; return; end if;
         Id := LE (Header, 0, 4); Length := LE (Header, 4, 2); Name_Length := LE (Header, 6, 1);
         if Length < 8 or else Length mod 4 /= 0 or else Length > V.Block_Size - Offset mod V.Block_Size or else
           Length > Parent.Length - Offset or else Name_Length > Length - 8 then Result := Corrupt; return; end if;
         if Id /= 0 and Name_Length = U64 (Name'Length) then
            Read_File (V, Parent, Offset + 8, Text (0 .. Name'Length - 1), Count, Result);
            if Result /= Success then return; end if;
            if Count = Name'Length and then Endian.Text (Text, 0, Name) then
               Object (V, Id, Item, Result); return;
            end if;
         end if;
         Offset := Offset + Length;
      end loop;
      Result := Not_Found;
   end Child;
end AxiomOS.Storage.Ext;
