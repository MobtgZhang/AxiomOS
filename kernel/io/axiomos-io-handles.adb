with AxiomOS.VFS.Mounts;
package body AxiomOS.IO.Handles is
   use type U64, U32, VFS.Node_Kind;
   function Resolve (Table : Handle_Table; Value : Handle) return Natural is
      Index : constant U64 := U64 (Value) mod 256;
      Generation : constant U64 := U64 (Value) / 256;
   begin
      if Index < 1 or else Index > Max_Handles or else
        not Table.Entries (Natural (Index)).Active or else
        U64 (Table.Entries (Natural (Index)).Generation) /= Generation
      then return 0; end if;
      return Natural (Index);
   end Resolve;
   procedure Open (Table : in out Handle_Table; FS : in out VFS.File_System;
                   Path : String; Permissions : Rights;
                   Value : out Handle; Result : out Status) is
      Node : VFS.Node_Id;
   begin
      Value := Invalid_Handle;
      if not Permissions.Read and not Permissions.Write then
         Result := Invalid_Argument;
         return;
      end if;
      VFS.Mounts.Lookup (FS, Path, Node, Result);
      if Result /= Success then return; end if;
      if FS.Nodes (Node).Kind not in VFS.Regular | VFS.Character_Device then
         Result := Invalid_Argument;
         return;
      elsif Permissions.Write and FS.Nodes (Node).Read_Only then
         Result := Permission_Denied;
         return;
      end if;
      for I in Table.Entries'Range loop
         if not Table.Entries (I).Active and then Table.Entries (I).Generation /= 0
         then
            Table.Entries (I).Active := True;
            Table.Entries (I).Node := Node;
            Table.Entries (I).Offset := 0;
            Table.Entries (I).Permissions := Permissions;
            FS.Nodes (Node).Open_Count := FS.Nodes (Node).Open_Count + 1;
            Value := Handle (U64 (Table.Entries (I).Generation) * 256 + U64 (I));
            Result := Success;
            return;
         end if;
      end loop;
      Result := No_Space;
   end Open;
   procedure Close (Table : in out Handle_Table; FS : in out VFS.File_System; Value : Handle;
                    Result : out Status) is
      I : constant Natural := Resolve (Table, Value);
   begin
      Result := Bad_Handle;
      if I = 0 then return; end if;
      if FS.Nodes (Table.Entries (I).Node).Open_Count = 0 then Result := Corrupt; return; end if;
      FS.Nodes (Table.Entries (I).Node).Open_Count := FS.Nodes (Table.Entries (I).Node).Open_Count - 1;
      Table.Entries (I).Active := False;
      -- A generation that wraps to zero permanently retires this slot.
      Table.Entries (I).Generation := Table.Entries (I).Generation + 1;
      Result := Success;
   end Close;
   procedure Close_All (Table : in out Handle_Table; FS : in out VFS.File_System) is
      S : Status;
   begin
      for I in Table.Entries'Range loop
         if Table.Entries (I).Active then
            Close (Table, FS, Handle (U64 (Table.Entries (I).Generation) * 256 + U64 (I)), S);
         end if;
      end loop;
   end Close_All;
   procedure Duplicate (Table : in out Handle_Table; FS : in out VFS.File_System;
                        Source : Handle; Permissions : Rights;
                        Value : out Handle; Result : out Status) is
      J : constant Natural := Resolve (Table, Source);
   begin
      Value := Invalid_Handle; Result := Bad_Handle;
      if J = 0 then return; end if;
      Result := Permission_Denied;
      if (Permissions.Read and then not Table.Entries (J).Permissions.Read) or else
        (Permissions.Write and then not Table.Entries (J).Permissions.Write) then return; end if;
      Result := Invalid_Argument;
      if not Permissions.Read and not Permissions.Write then return; end if;
      for I in Table.Entries'Range loop
         if not Table.Entries (I).Active and then Table.Entries (I).Generation /= 0 then
            Table.Entries (I).Node := Table.Entries (J).Node;
            Table.Entries (I).Offset := Table.Entries (J).Offset;
            Table.Entries (I).Permissions := Permissions;
            Table.Entries (I).Active := True;
            FS.Nodes (Table.Entries (I).Node).Open_Count := FS.Nodes (Table.Entries (I).Node).Open_Count + 1;
            Value := Handle (U64 (Table.Entries (I).Generation) * 256 + U64 (I));
            Result := Success; return;
         end if;
      end loop;
      Result := No_Space;
   end Duplicate;
end AxiomOS.IO.Handles;
