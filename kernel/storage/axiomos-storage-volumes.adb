with AxiomOS.Storage.Ext;
with AxiomOS.Storage.FAT;
with AxiomOS.Storage.NTFS;
with AxiomOS.Storage.Endian;
with AxiomOS.VFS.Paths;
package body AxiomOS.Storage.Volumes is
   use type U64;
   procedure Mount (Disk : Device; V : out Volume; Result : out Status) is
      Boot : Bytes (0 .. 511); Super : Bytes (0 .. 1);
   begin
      V := (Disk => Disk, others => <>);
      Storage.Read (Disk, 0, Boot, Result);
      if Result /= Success then return; end if;
      if Endian.Text (Boot, 3, "NTFS    ") then NTFS.Mount (V, Result); return; end if;
      Storage.Read (Disk, 1080, Super, Result);
      if Result /= Success then return; end if;
      if Endian.LE (Super, 0, 2) = 16#EF53# then Ext.Mount (V, Result);
      else FAT.Mount (V, Result); end if;
   end Mount;
   procedure Lookup (V : Volume; Path : String; Item : out File_Object; Result : out Status) is
      Canonical : String (1 .. 127);
      Length, First, Last : Natural;
      Parent : File_Object;
   begin
      Item := (others => <>);
      VFS.Paths.Normalize (Path, Canonical, Length, Result);
      if Result /= Success then return; end if;
      Item := V.Root; First := 2;
      while First <= Length loop
         Last := First;
         while Last < Length and then Canonical (Last + 1) /= '/' loop Last := Last + 1; end loop;
         Parent := Item;
         case V.Kind is
            when EXT2 | EXT3 | EXT4 => Ext.Child (V, Parent, Canonical (First .. Last), Item, Result);
            when FAT16 | FAT32 => FAT.Child (V, Parent, Canonical (First .. Last), Item, Result);
            when NTFS_Volume => NTFS.Child (V, Parent, Canonical (First .. Last), Item, Result);
            when Unknown => Result := Invalid_Argument;
         end case;
         if Result /= Success then return; end if;
         First := Last + 2;
      end loop;
   end Lookup;
   procedure Read_File (V : Volume; Item : File_Object; Offset : U64;
                        Buffer : out Bytes; Count : out Natural; Result : out Status) is
   begin
      Buffer := (others => 0); Count := 0; Result := Invalid_Argument;
      if Item.Directory then return; end if;
      case V.Kind is
         when EXT2 | EXT3 | EXT4 => Ext.Read_File (V, Item, Offset, Buffer, Count, Result);
         when FAT16 | FAT32 => FAT.Read_File (V, Item, Offset, Buffer, Count, Result);
         when NTFS_Volume => NTFS.Read_File (V, Item, Offset, Buffer, Count, Result);
         when Unknown => null;
      end case;
   end Read_File;
end AxiomOS.Storage.Volumes;
