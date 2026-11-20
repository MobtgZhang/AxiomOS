with AxiomOS.VFS.Paths;
with AxiomOS.VFS.Tmpfs;
with AxiomOS.Storage.Volumes;
package body AxiomOS.VFS.Mounts is
   use type U64, Storage.Format;
   function Prefix (Path, Parent : String) return Boolean is
     (Parent = "/" or else (Path'Length >= Parent'Length and then
      Path (Path'First .. Path'First + Parent'Length - 1) = Parent and then
      (Path'Length = Parent'Length or else Path (Path'First + Parent'Length) = '/')));
   function Resolve (FS : File_System; Canonical : String) return Mount_Id is
      Best : Mount_Id := 1;
   begin
      for I in FS.Mounts'Range loop
         if FS.Mounts (I).Active and then FS.Mounts (I).Path_Length > FS.Mounts (Best).Path_Length
           and then Prefix (Canonical, FS.Mounts (I).Path (1 .. FS.Mounts (I).Path_Length))
         then Best := I; end if;
      end loop;
      return Best;
   end Resolve;
   procedure Mount_Root (FS : in out File_System; Disk : Storage.Device; Result : out Status) is
      V : Storage.Volume;
   begin
      for N of FS.Nodes loop
         if N.Open_Count /= 0 then Result := Busy; return; end if;
      end loop;
      for I in 2 .. Max_Mounts loop
         if FS.Mounts (I).Active then Result := Busy; return; end if;
      end loop;
      Storage.Volumes.Mount (Disk, V, Result);
      if Result /= Success then return; end if;
      Tmpfs.Initialize (FS); FS.Root_Volume := V;
      FS.Mounts (1).Memory_Backed := False;
      FS.Nodes (1).Read_Only := True;
   end Mount_Root;
   procedure Install (FS : in out File_System; Path : String;
                      Memory_Backed : Boolean; V : Storage.Volume; Result : out Status) is
      Canonical : String (1 .. Max_Path);
      Length : Natural;
      Id : Node_Id;
      Slot : Natural := 0;
   begin
      Paths.Normalize (Path, Canonical, Length, Result);
      if Result /= Success then return; end if;
      if Length = 1 then Result := Invalid_Argument; return; end if;
      for M of FS.Mounts loop
         if M.Active and then Prefix (M.Path (1 .. M.Path_Length), Canonical (1 .. Length)) then
            Result := Busy; return;
         end if;
      end loop;
      for N of FS.Nodes loop
         if N.Kind /= Unused and then N.Open_Count /= 0 and then
           Prefix (N.Path (1 .. N.Path_Length), Canonical (1 .. Length)) then Result := Busy; return; end if;
      end loop;
      Lookup (FS, Canonical (1 .. Length), Id, Result);
      if Result /= Success then return; end if;
      if FS.Nodes (Id).Kind /= Directory then Result := Invalid_Argument; return; end if;
      for I in 2 .. Max_Mounts loop
         if not FS.Mounts (I).Active then Slot := I; exit; end if;
      end loop;
      if Slot = 0 then Result := No_Space; return; end if;
      -- A mounted root has its own node; the covered node survives unmount.
      for I in FS.Nodes'Range loop
         if FS.Nodes (I).Kind = Unused then
            FS.Mounts (Slot) := (True, Memory_Backed, Canonical, Length, V);
            FS.Nodes (I) := (others => <>);
            FS.Nodes (I).Kind := Directory; FS.Nodes (I).Mount := Slot;
            FS.Nodes (I).Path := Canonical; FS.Nodes (I).Path_Length := Length;
            FS.Nodes (I).Read_Only := not Memory_Backed;
            Result := Success; return;
         end if;
      end loop;
      Result := No_Space;
   end Install;
   procedure Mount_Disk (FS : in out File_System; Path : String;
                         Disk : Storage.Device; Result : out Status) is
      V : Storage.Volume;
   begin
      Storage.Volumes.Mount (Disk, V, Result);
      if Result = Success then Install (FS, Path, False, V, Result); end if;
   end Mount_Disk;
   procedure Mount_Tmpfs (FS : in out File_System; Path : String; Result : out Status) is
      V : Storage.Volume;
   begin Install (FS, Path, True, V, Result); end Mount_Tmpfs;
   procedure Unmount (FS : in out File_System; Path : String; Result : out Status) is
      Canonical : String (1 .. Max_Path);
      Length : Natural;
      Slot : Mount_Id;
   begin
      Paths.Normalize (Path, Canonical, Length, Result);
      if Result /= Success then return; end if;
      Result := Invalid_Argument;
      if Length = 1 then return; end if;
      Slot := Resolve (FS, Canonical (1 .. Length));
      Result := Not_Found;
      if Slot = 1 or else FS.Mounts (Slot).Path_Length /= Length then return; end if;
      for I in FS.Mounts'Range loop
         if I /= Slot and then FS.Mounts (I).Active and then
           Prefix (FS.Mounts (I).Path (1 .. FS.Mounts (I).Path_Length), Canonical (1 .. Length)) then
            Result := Busy; return;
         end if;
      end loop;
      for N of FS.Nodes loop
         if N.Kind /= Unused and then N.Mount = Slot and then N.Open_Count /= 0 then Result := Busy; return; end if;
      end loop;
      for N of FS.Nodes loop
         if N.Kind /= Unused and then N.Mount = Slot then N := (others => <>); end if;
      end loop;
      FS.Mounts (Slot) := (others => <>); Result := Success;
   end Unmount;
   procedure Lookup (FS : in out File_System; Path : String; Id : out Node_Id; Result : out Status) is
      Item : Storage.File_Object;
      Canonical : String (1 .. Max_Path);
      Length, Skip : Natural;
      Slot : Mount_Id;
   begin
      Id := 0;
      Paths.Normalize (Path, Canonical, Length, Result);
      if Result /= Success then return; end if;
      Slot := Resolve (FS, Canonical (1 .. Length));
      for I in FS.Nodes'Range loop
         if FS.Nodes (I).Kind /= Unused and then FS.Nodes (I).Mount = Slot and then
           FS.Nodes (I).Path_Length = Length and then FS.Nodes (I).Path (1 .. Length) = Canonical (1 .. Length)
         then Id := I; Result := Success; return; end if;
      end loop;
      Result := Not_Found;
      if FS.Mounts (Slot).Memory_Backed then return; end if;
      Skip := (if Slot = 1 then 0 else FS.Mounts (Slot).Path_Length);
      if Slot = 1 then
         Storage.Volumes.Lookup (FS.Root_Volume, Canonical (1 .. Length), Item, Result);
      else
         Storage.Volumes.Lookup (FS.Mounts (Slot).Disk, Canonical (Skip + 1 .. Length), Item, Result);
      end if;
      if Result /= Success then return; end if;
      if Item.Length > U64 (Natural'Last) then Result := Unsupported; return; end if;
      for I in FS.Nodes'Range loop
         if FS.Nodes (I).Kind = Unused then
            FS.Nodes (I) := (others => <>);
            FS.Nodes (I).Kind := (if Item.Directory then Directory else Regular);
            FS.Nodes (I).Mount := Slot;
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
         if FS.Nodes (Id).Mount = 1 then
            Storage.Volumes.Read_File (FS.Root_Volume, FS.Nodes (Id).Object, Offset, Buffer, Count, Result);
         else
            Storage.Volumes.Read_File (FS.Mounts (FS.Nodes (Id).Mount).Disk,
              FS.Nodes (Id).Object, Offset, Buffer, Count, Result);
         end if;
      else Tmpfs.Read (FS, Id, Offset, Buffer, Count, Result); end if;
   end Read;
   procedure Write (FS : in out File_System; Id : Node_Id; Offset : U64;
                    Buffer : Bytes; Count : out Natural; Result : out Status) is
   begin Tmpfs.Write (FS, Id, Offset, Buffer, Count, Result); end Write;
end AxiomOS.VFS.Mounts;
