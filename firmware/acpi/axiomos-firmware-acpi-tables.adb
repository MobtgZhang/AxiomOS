with AxiomOS.Raw;
package body AxiomOS.Firmware.ACPI.Tables is
   use type U8, U32, U64;
   function Checksum (Base, Length : U64) return Boolean is
      Sum : U8 := 0;
   begin
      if Length = 0 or else Length > 1024 * 1024 or else not Fits (Base, Length)
      then return False; end if;
      for I in 0 .. Length - 1 loop Sum := Sum + Raw.Load8 (Base + I); end loop;
      return Sum = 0;
   end Checksum;
   procedure Find (RSDP : U64; Signature : U32; Table : out U64; Result : out Status) is
      Root, Size, Width, P : U64;
   begin
      Table := 0; Result := Not_Found;
      if RSDP = 0 then return; end if;
      Result := Corrupt;
      if Raw.Load64 (RSDP) /= 16#2052545020445352# or else not Checksum (RSDP, 20) then return; end if;
      if Raw.Load8 (RSDP + 15) >= 2 then
         if not Checksum (RSDP, U64 (Raw.Load32 (RSDP + 20))) then return; end if;
         Root := Raw.Load64 (RSDP + 24); Width := 8;
      else Root := U64 (Raw.Load32 (RSDP + 16)); Width := 4; end if;
      if Root = 0 then return; end if;
      Size := U64 (Raw.Load32 (Root + 4));
      if Size < 36 or else (Size - 36) mod Width /= 0 or else not Checksum (Root, Size) then return; end if;
      for I in 0 .. Natural ((Size - 36) / Width) - 1 loop
         P := (if Width = 8 then Raw.Load64 (Root + 36 + U64 (I) * Width)
               else U64 (Raw.Load32 (Root + 36 + U64 (I) * Width)));
         if P /= 0 and then Raw.Load32 (P) = Signature then
            if not Checksum (P, U64 (Raw.Load32 (P + 4))) then return; end if;
            Table := P; Result := Success; return;
         end if;
      end loop;
      Result := Not_Found;
   end Find;
   procedure Parse_Topology (RSDP : U64; Description : out Topology;
                             Result : out Status) is
      Root, Table, Size, Count, Width, Cursor, Length, Hardware_Id : U64;
      Kind : U8;
      Enabled, Duplicate : Boolean;
   begin
      Description := (others => <>);
      Result := Not_Found;
      if RSDP = 0 then return; end if;
      Result := Corrupt;
      if Raw.Load64 (RSDP) /= 16#2052545020445352# or else
        not Checksum (RSDP, 20)
      then return; end if;
      if Raw.Load8 (RSDP + 15) >= 2 then
         Size := U64 (Raw.Load32 (RSDP + 20));
         if Size < 36 or else not Checksum (RSDP, Size) then return; end if;
         Root := Raw.Load64 (RSDP + 24); Width := 8;
      else Root := U64 (Raw.Load32 (RSDP + 16)); Width := 4;
      end if;
      if Root = 0 then return; end if;
      Size := U64 (Raw.Load32 (Root + 4));
      if Size < 36 or else (Size - 36) mod Width /= 0 or else
        not Checksum (Root, Size)
      then return; end if;
      Count := (Size - 36) / Width;
      if Count = 0 then return; end if;
      for I in 0 .. Count - 1 loop
         Table := (if Width = 8 then Raw.Load64 (Root + 36 + I * Width)
                   else U64 (Raw.Load32 (Root + 36 + I * Width)));
         if Table /= 0 and then Raw.Load32 (Table) = 16#43495041# then
            Size := U64 (Raw.Load32 (Table + 4));
            if Size < 44 or else not Checksum (Table, Size) then return; end if;
            Description.Local_APIC := U64 (Raw.Load32 (Table + 36));
            Cursor := 44;
            while Cursor < Size loop
               if Size - Cursor < 2 then return; end if;
               Kind := Raw.Load8 (Table + Cursor);
               Length := U64 (Raw.Load8 (Table + Cursor + 1));
               if Length < 2 or else Length > Size - Cursor then return; end if;
               Enabled := False; Hardware_Id := 0;
               if Kind = 0 and then Length >= 8 then
                  Hardware_Id := U64 (Raw.Load8 (Table + Cursor + 3));
                  Enabled := (Raw.Load32 (Table + Cursor + 4) and 1) /= 0;
               elsif Kind = 9 and then Length >= 16 then
                  Hardware_Id := U64 (Raw.Load32 (Table + Cursor + 4));
                  Enabled := (Raw.Load32 (Table + Cursor + 8) and 1) /= 0;
               elsif Kind = 11 and then Length >= 76 then
                  Hardware_Id := Raw.Load64 (Table + Cursor + 68);
                  Enabled := (Raw.Load32 (Table + Cursor + 12) and 1) /= 0;
               elsif Kind = 17 and then Length >= 15 then
                  Hardware_Id := U64 (Raw.Load32 (Table + Cursor + 7));
                  Enabled := (Raw.Load32 (Table + Cursor + 11) and 1) /= 0;
               elsif Kind = 24 and then Length >= 36 then
                  Hardware_Id := Raw.Load64 (Table + Cursor + 8);
                  Enabled := (Raw.Load32 (Table + Cursor + 4) and 1) /= 0;
               elsif Kind = 5 and then Length >= 12 then
                  Description.Local_APIC := Raw.Load64 (Table + Cursor + 4);
               end if;
               if Enabled then
                  if Description.Count = Description.CPUs'Length then
                     Result := No_Space; return;
                  end if;
                  Duplicate := False;
                  for J in 0 .. Description.Count - 1 loop
                     if Description.CPUs (J).Hardware_Id = Hardware_Id then Duplicate := True; end if;
                  end loop;
                  if Duplicate then return; end if;
                  Description.CPUs (Description.Count) := (Hardware_Id, True);
                  Description.Count := Description.Count + 1;
               end if;
               Cursor := Cursor + Length;
            end loop;
            Result := Success;
            return;
         end if;
      end loop;
      Result := Not_Found;
   end Parse_Topology;
end AxiomOS.Firmware.ACPI.Tables;
