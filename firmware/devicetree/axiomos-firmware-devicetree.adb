with AxiomOS.Raw;
package body AxiomOS.Firmware.DeviceTree is
   use type U8, U32, U64;
   function BE32 (P : U64) return U64 is
     (U64 (Raw.Load8 (P)) * 2 ** 24 + U64 (Raw.Load8 (P + 1)) * 2 ** 16 +
      U64 (Raw.Load8 (P + 2)) * 256 + U64 (Raw.Load8 (P + 3)));
   function Timebase (Base : U64) return U64 is
      Total, Cursor, Last, Strings, String_End, Token, Size, Name : U64;
      Depth : Natural := 0;
      In_CPUs : Boolean := False;
      function Text (P, Limit : U64; Value : String) return Boolean is
      begin
         if P >= Limit or else U64 (Value'Length) >= Limit - P then return False; end if;
         for I in Value'Range loop
            if Raw.Load8 (P + U64 (I - Value'First)) /= Character'Pos (Value (I)) then return False; end if;
         end loop;
         return Raw.Load8 (P + U64 (Value'Length)) = 0;
      end Text;
   begin
      if Base = 0 or else BE32 (Base) /= 16#D00DFEED# then return 0; end if;
      Total := BE32 (Base + 4);
      if Total < 40 or else Total > 2 ** 20 or else not Fits (Base, Total) then return 0; end if;
      Cursor := BE32 (Base + 8); Strings := BE32 (Base + 12);
      if Cursor > Total or else BE32 (Base + 36) > Total - Cursor or else
         Strings > Total or else BE32 (Base + 32) > Total - Strings then return 0; end if;
      Last := Base + Cursor + BE32 (Base + 36);
      String_End := Base + Strings + BE32 (Base + 32);
      Cursor := Base + Cursor; Strings := Base + Strings;
      while Cursor < Last and then Last - Cursor >= 4 loop
         Token := BE32 (Cursor); Cursor := Cursor + 4;
         case Token is
            when 1 =>
               Depth := Depth + 1;
               if Depth > 64 then return 0; end if;
               if Depth = 2 then In_CPUs := Text (Cursor, Last, "cpus"); end if;
               while Cursor < Last and then Raw.Load8 (Cursor) /= 0 loop Cursor := Cursor + 1; end loop;
               if Cursor = Last then return 0; end if;
               Cursor := (Cursor + 4) / 4 * 4;
            when 2 =>
               if Depth = 0 then return 0; end if;
               if Depth = 2 then In_CPUs := False; end if;
               Depth := Depth - 1;
            when 3 =>
               if Last - Cursor < 8 then return 0; end if;
               Size := BE32 (Cursor); Name := BE32 (Cursor + 4); Cursor := Cursor + 8;
               if Size > Last - Cursor or else Name >= String_End - Strings then return 0; end if;
               if In_CPUs and then Depth = 2 and then Size = 4 and then
                 Text (Strings + Name, String_End, "timebase-frequency") then return BE32 (Cursor); end if;
               Cursor := (Cursor + Size + 3) / 4 * 4;
            when 4 => null;
            when others => return 0;
         end case;
      end loop;
      return 0;
   end Timebase;
   procedure CPUs (Base : U64; List : out ACPI.Topology; Result : out Status) is
      Total, Struct, Strings, End_Struct, End_Strings, Cursor, Token, Size, Name, Id : U64;
      Depth : Natural := 0;
      CPU_Depth : Natural := 0;
      Cells : U64 := 1;
      Candidate, Disabled, Has_Id : Boolean := False;
      function Equals (P, Limit : U64; Text : String) return Boolean is
      begin
         if P > Limit or else U64 (Text'Length) >= Limit - P then return False; end if;
         for I in Text'Range loop
            if Raw.Load8 (P + U64 (I - Text'First)) /= Character'Pos (Text (I)) then return False; end if;
         end loop;
         return Raw.Load8 (P + U64 (Text'Length)) = 0;
      end Equals;
      function Within (Offset, Length : U64) return Boolean is
        (Offset <= Total and then Length <= Total - Offset);
   begin
      List := (others => <>);
      Result := Not_Found;
      if Base = 0 then return; end if;
      Result := Corrupt;
      if BE32 (Base) /= 16#D00DFEED# then return; end if;
      Total := BE32 (Base + 4);
      if Total < 40 or else Total > 2 ** 20 or else not Fits (Base, Total) then return; end if;
      Struct := BE32 (Base + 8); Strings := BE32 (Base + 12);
      if not Within (Struct, BE32 (Base + 36)) or else
        not Within (Strings, BE32 (Base + 32)) then return; end if;
      End_Struct := Base + Struct + BE32 (Base + 36);
      End_Strings := Base + Strings + BE32 (Base + 32);
      Strings := Base + Strings;
      Cursor := Base + Struct;
      while Cursor <= End_Struct and then End_Struct - Cursor >= 4 loop
         Token := BE32 (Cursor); Cursor := Cursor + 4;
         case Token is
            when 1 =>
               Depth := Depth + 1;
               if Depth > 64 then return; end if;
               if Equals (Cursor, End_Struct, "cpus") then CPU_Depth := Depth;
               elsif CPU_Depth > 0 and then Depth = CPU_Depth + 1 then
                  Candidate := False; Disabled := False; Has_Id := False; Id := 0;
               end if;
               while Cursor < End_Struct and then Raw.Load8 (Cursor) /= 0 loop Cursor := Cursor + 1; end loop;
               if Cursor = End_Struct then return; end if;
               Cursor := (Cursor + 4) / 4 * 4;
            when 2 =>
               if Depth = 0 then return; end if;
               if CPU_Depth > 0 and then Depth = CPU_Depth + 1 and then Candidate
                 and then not Disabled and then Has_Id then
                  if List.Count = List.CPUs'Length then Result := No_Space; return; end if;
                  for I in 0 .. List.Count - 1 loop
                     if List.CPUs (I).Hardware_Id = Id then return; end if;
                  end loop;
                  List.CPUs (List.Count) := (Id, True); List.Count := List.Count + 1;
               end if;
               if Depth = CPU_Depth then CPU_Depth := 0; end if;
               Depth := Depth - 1;
            when 3 =>
               if End_Struct - Cursor < 8 then return; end if;
               Size := BE32 (Cursor); Name := BE32 (Cursor + 4); Cursor := Cursor + 8;
               if Size > End_Struct - Cursor or else Name >= End_Strings - Strings then return; end if;
               Name := Strings + Name;
               if CPU_Depth > 0 and Depth = CPU_Depth then
                  if Equals (Name, End_Strings, "#address-cells") and then Size = 4 then
                     Cells := BE32 (Cursor);
                     if Cells /= 1 and Cells /= 2 then return; end if;
                  end if;
               elsif CPU_Depth > 0 and Depth = CPU_Depth + 1 then
                  if Equals (Name, End_Strings, "device_type") then
                     Candidate := Equals (Cursor, Cursor + Size, "cpu");
                  elsif Equals (Name, End_Strings, "status") then
                     Disabled := not Equals (Cursor, Cursor + Size, "okay") and
                       not Equals (Cursor, Cursor + Size, "ok");
                  elsif Equals (Name, End_Strings, "reg") and then Size = Cells * 4 then
                     Id := BE32 (Cursor);
                     if Cells = 2 then Id := Id * 2 ** 32 + BE32 (Cursor + 4); end if;
                     Has_Id := True;
                  end if;
               end if;
               Cursor := (Cursor + Size + 3) / 4 * 4;
            when 4 => null;
            when 9 =>
               if Depth /= 0 or List.Count = 0 then return; end if;
               Result := Success; return;
            when others => return;
         end case;
      end loop;
   end CPUs;
end AxiomOS.Firmware.DeviceTree;
