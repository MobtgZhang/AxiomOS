with AxiomOS.IO.Handles; use AxiomOS.IO.Handles;
with AxiomOS.VFS.Mounts;
with AxiomOS.IO.Console;
package body AxiomOS.IO.Streams is
   use type U64, VFS.Node_Kind;
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
