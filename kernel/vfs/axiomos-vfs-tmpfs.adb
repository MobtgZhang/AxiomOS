with AxiomOS.VFS.Paths; use AxiomOS.VFS.Paths;
with AxiomOS.VFS.Mounts;
package body AxiomOS.VFS.Tmpfs is
   use type U64;
   procedure Initialize (FS : in out File_System) is
   begin
      FS.Root_Volume := (others => <>);
      FS.Mounts := (others => <>);
      FS.Mounts (1).Active := True;
      FS.Mounts (1).Path (1) := '/';
      FS.Mounts (1).Path_Length := 1;
      for N of FS.Nodes loop
         N.Kind := Unused;
         N.Path := (others => Character'Val (0));
         N.Path_Length := 0;
         N.Read_Only := False;
         N.Length := 0;
         N.Backed := False; N.Object := (others => <>);
         N.Mount := 1; N.Open_Count := 0;
         N.Data := (others => 0);
      end loop;
      FS.Nodes (1).Kind := Directory;
      FS.Nodes (1).Path (1) := '/';
      FS.Nodes (1).Path_Length := 1;
   end Initialize;

   procedure Lookup (FS : File_System; Path : String;
                     Id : out Node_Id; Result : out Status) is
      Canonical : String (1 .. Max_Path);
      Length : Natural;
      Slot : Mount_Id;
   begin
      Id := 0;
      Normalize (Path, Canonical, Length, Result);
      if Result /= Success then return; end if;
      Slot := Mounts.Resolve (FS, Canonical (1 .. Length));
      for I in FS.Nodes'Range loop
         if FS.Nodes (I).Kind /= Unused and then
           FS.Nodes (I).Mount = Slot and then
           FS.Nodes (I).Path_Length = Length and then
           FS.Nodes (I).Path (1 .. Length) = Canonical (1 .. Length)
         then Id := I; return; end if;
      end loop;
      Result := Not_Found;
   end Lookup;

   procedure Create (FS : in out File_System; Path : String;
                     Kind : Node_Kind; Id : out Node_Id; Result : out Status) is
      Canonical : String (1 .. Max_Path);
      Length, Parent_End : Natural;
      Parent : Node_Id;
      Slot : Mount_Id;
   begin
      Id := 0;
      if Kind = Unused then Result := Invalid_Argument; return; end if;
      Normalize (Path, Canonical, Length, Result);
      if Result /= Success then return; end if;
      Slot := Mounts.Resolve (FS, Canonical (1 .. Length));
      if not FS.Mounts (Slot).Memory_Backed then Result := Permission_Denied; return; end if;
      Lookup (FS, Canonical (1 .. Length), Id, Result);
      if Result = Success then Result := Already_Exists; return; end if;
      Parent_End := Length;
      while Parent_End > 1 and then Canonical (Parent_End) /= '/' loop
         Parent_End := Parent_End - 1;
      end loop;
      Lookup (FS, Canonical (1 .. Natural'Max (1, Parent_End - 1)), Parent, Result);
      if Result /= Success then return; end if;
      if FS.Nodes (Parent).Kind /= Directory then
         Result := Invalid_Argument;
         return;
      end if;
      for I in FS.Nodes'Range loop
         if FS.Nodes (I).Kind = Unused then
            FS.Nodes (I) := (others => <>);
            FS.Nodes (I).Mount := Slot;
            FS.Nodes (I).Kind := Kind;
            FS.Nodes (I).Path := Canonical;
            FS.Nodes (I).Path_Length := Length;
            Id := I;
            Result := Success;
            return;
         end if;
      end loop;
      Id := 0;
      Result := No_Space;
   end Create;

   procedure Read (FS : File_System; Id : Node_Id; Offset : U64;
                   Buffer : out Bytes; Count : out Natural; Result : out Status) is
   begin
      Count := 0;
      Buffer := (others => 0);
      Result := Bad_Handle;
      if Id = 0 or else FS.Nodes (Id).Kind /= Regular then return; end if;
      Result := Success;
      if Offset >= U64 (FS.Nodes (Id).Length) then return; end if;
      Count := Natural'Min (Buffer'Length, FS.Nodes (Id).Length - Natural (Offset));
      for I in 0 .. Count - 1 loop
         Buffer (Buffer'First + I) := FS.Nodes (Id).Data (Natural (Offset) + I);
      end loop;
   end Read;

   procedure Write (FS : in out File_System; Id : Node_Id; Offset : U64;
                    Buffer : Bytes; Count : out Natural; Result : out Status) is
   begin
      Count := 0;
      Result := Bad_Handle;
      if Id = 0 or else FS.Nodes (Id).Kind /= Regular then return; end if;
      Result := Permission_Denied;
      if FS.Nodes (Id).Read_Only then return; end if;
      Result := No_Space;
      if Offset > Max_File_Size or else
        U64 (Buffer'Length) > U64 (Max_File_Size) - Offset
      then return; end if;
      Count := Buffer'Length;
      for I in 0 .. Count - 1 loop
         FS.Nodes (Id).Data (Natural (Offset) + I) := Buffer (Buffer'First + I);
      end loop;
      FS.Nodes (Id).Length := Natural'Max
        (FS.Nodes (Id).Length, Natural (Offset) + Count);
      Result := Success;
   end Write;

end AxiomOS.VFS.Tmpfs;
