with AxiomOS.Storage.Endian; use AxiomOS.Storage.Endian;
package body AxiomOS.Storage.FAT is
   use type U8, U64;
   procedure Mount (V : in out Volume; Result : out Status) is
      Boot : Bytes (0 .. 511);
      Sector_Size, Total, Reserved, Copies, FAT_Size, Clusters : U64;
   begin
      V.Kind := Unknown;
      Storage.Read (V.Disk, 0, Boot, Result);
      if Result /= Success then return; end if;
      Result := Corrupt;
      if LE (Boot, 510, 2) /= 16#AA55# then return; end if;
      Sector_Size := LE (Boot, 11, 2); Clusters := LE (Boot, 13, 1);
      if Sector_Size < 512 or else Sector_Size > 4096 or else not Power_Of_Two (Sector_Size) or else
        Clusters > 128 or else not Power_Of_Two (Clusters) then return; end if;
      V.Block_Size := Sector_Size * Clusters;
      Reserved := LE (Boot, 14, 2); Copies := LE (Boot, 16, 1);
      V.Root_Entries := LE (Boot, 17, 2); Total := LE (Boot, 19, 2);
      if Total = 0 then Total := LE (Boot, 32, 4); end if;
      FAT_Size := LE (Boot, 22, 2);
      if FAT_Size = 0 then FAT_Size := LE (Boot, 36, 4); end if;
      if Reserved = 0 or else Copies < 1 or else Copies > 2 or else FAT_Size = 0 then return; end if;
      V.FAT_Start := Reserved * Sector_Size;
      V.Root_Start := (Reserved + Copies * FAT_Size) * Sector_Size;
      V.Data_Start := V.Root_Start + ((V.Root_Entries * 32 + Sector_Size - 1) / Sector_Size) * Sector_Size;
      if Total * Sector_Size > V.Disk.Length or else Total * Sector_Size <= V.Data_Start then return; end if;
      V.Cluster_Count := (Total * Sector_Size - V.Data_Start) / V.Block_Size;
      if V.Cluster_Count < 4085 then Result := Unsupported; return;
      elsif V.Cluster_Count < 65525 then
         if V.Root_Entries = 0 or else LE (Boot, 22, 2) = 0 or else
           FAT_Size * Sector_Size / 2 < V.Cluster_Count + 2 then return; end if;
         V.Kind := FAT16; V.Root := (0, V.Root_Entries * 32, True);
      else
         if V.Cluster_Count >= 16#0FFF_FFF5# or else V.Root_Entries /= 0 or else LE (Boot, 22, 2) /= 0 or else
           LE (Boot, 42, 2) /= 0 or else FAT_Size * Sector_Size / 4 < V.Cluster_Count + 2 then return; end if;
         V.Root := (LE (Boot, 44, 4), 0, True); V.Kind := FAT32;
         if V.Root.Id < 2 or else V.Root.Id >= V.Cluster_Count + 2 then V.Kind := Unknown; return; end if;
         if (LE (Boot, 40, 2) and 128) /= 0 then
            if (LE (Boot, 40, 2) and 15) >= Copies then V.Kind := Unknown; return; end if;
            V.FAT_Start := V.FAT_Start + (LE (Boot, 40, 2) and 15) * FAT_Size * Sector_Size;
         end if;
      end if;
      Result := Success;
   end Mount;
   procedure Next (V : Volume; Cluster : in out U64; Result : out Status) is
      Word : Bytes (0 .. 3);
      Width : constant Natural := (if V.Kind = FAT16 then 2 else 4);
   begin
      Result := Corrupt;
      if Cluster < 2 or else Cluster >= V.Cluster_Count + 2 then return; end if;
      Storage.Read (V.Disk, V.FAT_Start + Cluster * U64 (Width), Word (0 .. Width - 1), Result);
      if Result /= Success then return; end if;
      Cluster := LE (Word, 0, Width) and (if Width = 2 then 16#FFFF# else 16#0FFF_FFFF#);
      if Cluster >= (if Width = 2 then 16#FFF8# else 16#0FFF_FFF8#) then Cluster := 0;
      elsif Cluster < 2 or else Cluster >= V.Cluster_Count + 2 then Result := Corrupt;
      end if;
   end Next;
   procedure Read_File (V : Volume; Item : File_Object; Offset : U64;
                        Buffer : out Bytes; Count : out Natural; Result : out Status) is
      Cluster : U64 := Item.Id;
      Cursor : U64 := Offset;
      Amount, Goal : Natural;
      Skip : U64;
      Slow, Fast : U64 := Item.Id;
      Steps : Natural := 0;
      procedure Advance is
      begin
         if Steps = 65536 then Result := Unsupported; return; end if;
         Steps := Steps + 1;
         Next (V, Cluster, Result);
         if Result /= Success or else Fast = 0 then return; end if;
         Next (V, Fast, Result);
         if Result /= Success then return; end if;
         if Fast /= 0 then Next (V, Fast, Result); end if;
         if Result /= Success then return; end if;
         Next (V, Slow, Result);
         if Result /= Success then return; end if;
         if Fast /= 0 and then Fast = Slow then Result := Corrupt; end if;
      end Advance;
   begin
      Buffer := (others => 0); Count := 0; Result := Success;
      if Offset >= Item.Length or Buffer'Length = 0 then return; end if;
      Goal := Natural (U64'Min (U64 (Buffer'Length), Item.Length - Offset));
      if Cluster = 0 and Item.Directory and V.Kind = FAT16 then
         Storage.Read (V.Disk, V.Root_Start + Offset,
                       Buffer (Buffer'First .. Buffer'First + Goal - 1), Result);
         if Result = Success then Count := Goal; end if;
         return;
      end if;
      Skip := Offset / V.Block_Size;
      if Skip >= V.Cluster_Count or else Skip > 65536 then Result := Corrupt; return; end if;
      for I in 1 .. Skip loop
         Advance;
         if Result /= Success then return; end if;
         if Cluster = 0 then Result := Corrupt; return; end if;
      end loop;
      while Count < Goal loop
         if Cluster < 2 or else Cluster >= V.Cluster_Count + 2 then Result := Corrupt; return; end if;
         Amount := Natural'Min (Goal - Count, Natural (V.Block_Size - Cursor mod V.Block_Size));
         Storage.Read (V.Disk, V.Data_Start + (Cluster - 2) * V.Block_Size + Cursor mod V.Block_Size,
           Buffer (Buffer'First + Count .. Buffer'First + Count + Amount - 1), Result);
         if Result /= Success then return; end if;
         Count := Count + Amount; Cursor := Cursor + U64 (Amount);
         if Count < Goal then
            Advance;
            if Result /= Success then return; end if;
         end if;
      end loop;
   end Read_File;
   procedure Child (V : Volume; Parent : File_Object; Name : String;
                    Item : out File_Object; Result : out Status) is
      Dir : File_Object := Parent;
      Data : Bytes (0 .. 31);
      Offset : U64 := 0;
      Count, Len, Ordinal, Expected : Natural := 0;
      Long_Name : String (1 .. 260) := (others => Character'Val (0));
      Short_Name : String (1 .. 12);
      Checksum, Sum : U8 := 0;
      Valid_Long : Boolean := False;
      Positions : constant array (1 .. 13) of Natural := (1, 3, 5, 7, 9, 14, 16, 18, 20, 22, 24, 28, 30);
      C : U64;
   begin
      Item := (others => <>); Result := Invalid_Argument;
      if not Parent.Directory or Name'Length = 0 or Name'Length > 255 then return; end if;
      -- A bounded scan protects the kernel against cyclic or unreasonable directory chains.
      if Dir.Length = 0 then Dir.Length := U64' Min (V.Cluster_Count * V.Block_Size, 8 * 1024 * 1024); end if;
      while Offset < Dir.Length loop
         Read_File (V, Dir, Offset, Data, Count, Result);
         if Result /= Success then return; end if;
         if Count /= 32 then Result := Corrupt; return; end if;
         if Data (0) = 0 then Result := Not_Found; return; end if;
         if Data (0) = 16#E5# then Valid_Long := False;
         elsif Data (11) = 15 then
            Ordinal := Natural (Data (0) and 31);
            if (Data (0) and 64) /= 0 then
               Long_Name := (others => Character'Val (0)); Expected := Ordinal;
               Checksum := Data (13); Valid_Long := Ordinal in 1 .. 20;
            end if;
            if not Valid_Long or else Ordinal /= Expected or else Data (13) /= Checksum or else
              LE (Data, 26, 2) /= 0 or else Data (12) /= 0 then Valid_Long := False;
            else
               for I in 1 .. 13 loop
                  C := LE (Data, Positions (I), 2);
                  if C = 0 or C = 16#FFFF# then C := 0;
                  elsif C > 127 then Valid_Long := False; end if;
                  Long_Name ((Ordinal - 1) * 13 + I) := Character'Val (C mod 256);
               end loop;
               Expected := Expected - 1;
            end if;
         elsif (Data (11) and 8) = 0 then
            Len := 0; Short_Name := (others => ' '); Sum := 0;
            for I in 0 .. 10 loop
               Sum := (Sum / 2) + (Sum and 1) * 128 + Data (I);
            end loop;
            for I in 0 .. 7 loop
               exit when Data (I) = 32;
               Len := Len + 1; Short_Name (Len) := Character'Val (Data (I));
            end loop;
            if Data (8) /= 32 then
               Len := Len + 1; Short_Name (Len) := '.';
               for I in 8 .. 10 loop
                  exit when Data (I) = 32;
                  Len := Len + 1; Short_Name (Len) := Character'Val (Data (I));
               end loop;
            end if;
            if Valid_Long and Expected = 0 and Sum = Checksum then
               Len := 0;
               while Len < Long_Name'Length and then Long_Name (Len + 1) /= Character'Val (0) loop Len := Len + 1; end loop;
               Valid_Long := Equal_Name (Long_Name (1 .. Len), Name);
            else Valid_Long := False; end if;
            -- Recompute the short-name length independently from the LFN length.
            Len := 0;
            while Len < Short_Name'Length and then Short_Name (Len + 1) /= ' ' loop Len := Len + 1; end loop;
            if Valid_Long or else Equal_Name (Short_Name (1 .. Len), Name) then
               Item := (LE (Data, 26, 2), LE (Data, 28, 4), (Data (11) and 16) /= 0);
               if V.Kind = FAT32 then Item.Id := Item.Id + LE (Data, 20, 2) * 65536; end if;
               if Item.Id = 0 and then Item.Length /= 0 then Result := Corrupt; return; end if;
               Result := Success; return;
            end if;
            Valid_Long := False;
         else Valid_Long := False;
         end if;
         Offset := Offset + 32;
      end loop;
      Result := Not_Found;
   end Child;
end AxiomOS.Storage.FAT;
