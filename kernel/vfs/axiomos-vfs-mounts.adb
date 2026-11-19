with AxiomOS.VFS.Paths;
with AxiomOS.VFS.Tmpfs;
with AxiomOS.Storage.Volumes;
package body AxiomOS.VFS.Mounts is
   use type U64, Storage.Format;
   procedure Mount_Root (FS : in out File_System; Disk : Storage.Device; Result : out Status) is
      V : Storage.Volume;
   begin
      Storage.Volumes.Mount (Disk, V, Result);
      if Result /= Success then return; end if;
      -- Mount is only valid before handles are published to processes.
      Tmpfs.Initialize (FS); FS.Root_Volume := V;
   end Mount_Root;
   procedure Lookup (FS : in out File_System; Path : String; Id : out Node_Id; Result : out Status) is
      Item : Storage.File_Object;
      Canonical : String (1 .. Max_Path);
      Length : Natural;
   begin
      Tmpfs.Lookup (FS, Path, Id, Result);
      if Result /= Not_Found or else FS.Root_Volume.Kind = Storage.Unknown then return; end if;
      Paths.Normalize (Path, Canonical, Length, Result);
      if Result /= Success then return; end if;
      Storage.Volumes.Lookup (FS.Root_Volume, Canonical (1 .. Length), Item, Result);
      if Result /= Success then return; end if;
      if Item.Length > U64 (Natural'Last) then Result := Unsupported; return; end if;
      for I in FS.Nodes'Range loop
         if FS.Nodes (I).Kind = Unused then
            FS.Nodes (I).Kind := (if Item.Directory then Directory else Regular);
            FS.Nodes (I).Path := Canonical; FS.Nodes (I).Path_Length := Length;
            FS.Nodes (I).Length := Natural (Item.Length);
            FS.Nodes (I).Read_Only := True; FS.Nodes (I).Backed := True;
            FS.Nodes (I).Object := Item; Id := I; Result := Success; return;
         end if;
      end loop;
      Result := No_Space;
   end Lookup;
   procedure Read (FS : File_System; Id : Node_Id; Offset : U64;
                   Buffer : out Bytes; Count : out Natural; Result : out Status) is
   begin
      Buffer := (others => 0); Count := 0; Result := Bad_Handle;
      if Id = 0 or else FS.Nodes (Id).Kind /= Regular then return; end if;
      if FS.Nodes (Id).Backed then
         Storage.Volumes.Read_File (FS.Root_Volume, FS.Nodes (Id).Object, Offset, Buffer, Count, Result);
      else Tmpfs.Read (FS, Id, Offset, Buffer, Count, Result); end if;
   end Read;
   procedure Write (FS : in out File_System; Id : Node_Id; Offset : U64;
                    Buffer : Bytes; Count : out Natural; Result : out Status) is
   begin
      Tmpfs.Write (FS, Id, Offset, Buffer, Count, Result);
   end Write;
end AxiomOS.VFS.Mounts;
