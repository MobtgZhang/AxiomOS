with AxiomOS.IO.Handles; use AxiomOS.IO.Handles;
with AxiomOS.VFS.Mounts;
with AxiomOS.IO.Console;
package body AxiomOS.IO.Streams is
   use type U64, VFS.Node_Kind;
   use type I64;
   procedure Seek (Table : in out Handle_Table; FS : VFS.File_System;
                   Value : Handle; Offset : I64; Origin : Seek_Origin;
                   Position : out U64; Result : out Status) is
      I : constant Natural := Resolve (Table, Value);
      Base, Magnitude : U64;
   begin
      Position := 0; Result := Bad_Handle;
      if I = 0 then return; end if;
      Result := Unsupported;
      if FS.Nodes (Table.Entries (I).Node).Kind /= VFS.Regular then return; end if;
      Base := (case Origin is when Beginning => 0,
               when Current => Table.Entries (I).Offset,
               when Ending => U64 (FS.Nodes (Table.Entries (I).Node).Length));
      Result := Invalid_Argument;
      if Offset < 0 then
         Magnitude := U64 (-(Offset + 1)) + 1; -- I64'First has no positive I64 equivalent.
         if Magnitude > Base then return; end if;
         Position := Base - Magnitude;
      else
         Magnitude := U64 (Offset);
         if Magnitude > U64 (I64'Last) or else Base > U64 (I64'Last) - Magnitude then return; end if;
         Position := Base + Magnitude;
      end if;
      Table.Entries (I).Offset := Position; Result := Success;
   end Seek;
   procedure Stat (Table : Handle_Table; FS : VFS.File_System; Value : Handle;
                   Length : out U64; Kind : out VFS.Node_Kind; Result : out Status) is
      I : constant Natural := Resolve (Table, Value);
   begin
      Length := 0; Kind := VFS.Unused; Result := Bad_Handle;
      if I = 0 then return; end if;
      Length := U64 (FS.Nodes (Table.Entries (I).Node).Length);
      Kind := FS.Nodes (Table.Entries (I).Node).Kind; Result := Success;
   end Stat;
   procedure Read (Table : in out Handle_Table; FS : VFS.File_System;
                   Value : Handle; Buffer : out Bytes; Count : out Natural;
                   Result : out Status) is
      I : constant Natural := Resolve (Table, Value);
   begin
      Buffer := (others => 0);
      Count := 0;
      Result := Bad_Handle;
      if I = 0 then return; end if;
      Result := Permission_Denied;
      if not Table.Entries (I).Permissions.Read then return; end if;
      VFS.Mounts.Read (FS, Table.Entries (I).Node, Table.Entries (I).Offset,
                Buffer, Count, Result);
      if Result = Success then
         Table.Entries (I).Offset := Table.Entries (I).Offset + U64 (Count);
      end if;
   end Read;
   procedure Write (Table : in out Handle_Table; FS : in out VFS.File_System;
                    Value : Handle; Buffer : Bytes; Count : out Natural;
                    Result : out Status) is
      I : constant Natural := Resolve (Table, Value);
   begin
      Count := 0;
      Result := Bad_Handle;
      if I = 0 then return; end if;
      Result := Permission_Denied;
      if not Table.Entries (I).Permissions.Write then return; end if;
      if FS.Nodes (Table.Entries (I).Node).Kind = VFS.Character_Device then
         Console.Write (Buffer, Count, Result);
         return;
      end if;
      VFS.Mounts.Write (FS, Table.Entries (I).Node, Table.Entries (I).Offset,
                 Buffer, Count, Result);
      if Result = Success then
         Table.Entries (I).Offset := Table.Entries (I).Offset + U64 (Count);
      end if;
   end Write;
end AxiomOS.IO.Streams;
