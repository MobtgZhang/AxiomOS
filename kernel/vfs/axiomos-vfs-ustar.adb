with AxiomOS.VFS.Tmpfs; use AxiomOS.VFS.Tmpfs;
package body AxiomOS.VFS.Ustar is
   use type U8, U64;
   procedure Mount_Ustar (FS : in out File_System; Archive : Bytes;
                          Result : out Status) is
      Cursor : Natural := Archive'First;
      Size, Expected, Sum, Parsed : U64;
      Name : String (1 .. Max_Path);
      Name_Len, Count : Natural;
      Id : Node_Id;
      Valid : Boolean;
      function Octal (Offset, Length : Natural; Value : out U64) return Boolean is
         Digit : U8;
         Ended : Boolean := False;
      begin
         Value := 0;
         for I in 0 .. Length - 1 loop
            Digit := Archive (Cursor + Offset + I);
            if Digit = 0 or else Digit = 32 then
               Ended := Value /= 0 or else Ended;
            elsif Digit < 48 or else Digit > 55 or else Ended or else
              Value > (U64'Last - 7) / 8
            then return False;
            else Value := Value * 8 + U64 (Digit - 48);
            end if;
         end loop;
         return True;
      end Octal;
   begin
      Result := Corrupt;
      -- This bounded filesystem requires a complete, block-aligned ustar stream.
      if Archive'Length < 1024 or else Archive'Length mod 512 /= 0 then return; end if;
      while Cursor <= Archive'Last and then Archive'Last - Cursor >= 511 loop
         Sum := 0;
         for I in 0 .. 511 loop Sum := Sum + U64 (Archive (Cursor + I)); end loop;
         if Sum = 0 then
            if Archive'Last - Cursor < 1023 then return; end if;
            for I in 512 .. 1023 loop
               if Archive (Cursor + I) /= 0 then return; end if;
            end loop;
            Result := Success;
            return;
         end if;
         if Archive (Cursor + 257) /= Character'Pos ('u') or else
           Archive (Cursor + 258) /= Character'Pos ('s') or else
           Archive (Cursor + 259) /= Character'Pos ('t') or else
           Archive (Cursor + 260) /= Character'Pos ('a') or else
           Archive (Cursor + 261) /= Character'Pos ('r') or else
           Archive (Cursor + 345) /= 0
         then return; end if;
         if not Octal (148, 8, Expected) then return; end if;
         for I in 148 .. 155 loop
            Sum := Sum - U64 (Archive (Cursor + I)) + 32;
         end loop;
         if Sum /= Expected or else not Octal (124, 12, Size) then return; end if;
         if Size > Max_File_Size or else Size > U64 (Archive'Last - Cursor - 511)
         then return; end if;
         Name := (others => Character'Val (0));
         Name (1) := '/';
         Name_Len := 1;
         for I in 0 .. 99 loop
            exit when Archive (Cursor + I) = 0;
            Name_Len := Name_Len + 1;
            Name (Name_Len) := Character'Val (Archive (Cursor + I));
         end loop;
         Valid := Name_Len > 1 and then Name (2) /= '/';
         if not Valid then return; end if;
         if Archive (Cursor + 156) = Character'Pos ('5') then
            if Size /= 0 then return; end if;
            Create (FS, Name (1 .. Name_Len), Directory, Id, Result);
         elsif Archive (Cursor + 156) = Character'Pos ('0') or else
           Archive (Cursor + 156) = 0
         then
            Create (FS, Name (1 .. Name_Len), Regular, Id, Result);
            if Result /= Success then return; end if;
            Write (FS, Id, 0, Archive (Cursor + 512 .. Cursor + 511 + Natural (Size)),
                   Count, Result);
            FS.Nodes (Id).Read_Only := True;
         else
            Result := Unsupported;
            return;
         end if;
         if Result /= Success then return; end if;
         Parsed := ((Size + 511) / 512 + 1) * 512;
         Cursor := Cursor + Natural (Parsed);
         Result := Corrupt;
      end loop;
   end Mount_Ustar;
end AxiomOS.VFS.Ustar;
