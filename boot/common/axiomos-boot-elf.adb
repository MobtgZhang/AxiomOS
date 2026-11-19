package body AxiomOS.Boot.ELF is
   use type U8, U16, U32, U64;
   function LE16 (Image : Bytes; Offset : Natural) return U16 is
     (U16 (Image (Image'First + Offset)) +
      U16 (Image (Image'First + Offset + 1)) * 256);
   function LE32 (Image : Bytes; Offset : Natural) return U32 is
     (U32 (LE16 (Image, Offset)) + U32 (LE16 (Image, Offset + 2)) * 65536);
   function LE64 (Image : Bytes; Offset : Natural) return U64 is
     (U64 (LE32 (Image, Offset)) + U64 (LE32 (Image, Offset + 4)) * 2 ** 32);

   procedure Validate (Image : Bytes; Machine : U16; Plan : out Layout;
                       Result : out Status; Expected_Type : U16 := 3) is
      PH, Count, P, Kind, Flags, File_Offset, VA, FS, MS, Align : U64;
      Entry_Found : Boolean := False;
      function Within (Offset, Length : U64) return Boolean is
        (Offset <= U64 (Image'Length) and then
         Length <= U64 (Image'Length) - Offset);
   begin
      Plan := (others => <>);
      Result := Corrupt;
      if Image'Length < 64 then return; end if;
      if LE32 (Image, 0) /= 16#464C_457F# or else
        Image (Image'First + 4) /= 2 or else Image (Image'First + 5) /= 1 or else
        Image (Image'First + 6) /= 1 or else LE16 (Image, 16) /= Expected_Type or else
        LE16 (Image, 18) /= Machine or else LE32 (Image, 20) /= 1 or else
        LE16 (Image, 52) /= 64 or else LE16 (Image, 54) /= 56
      then return; end if;
      PH := LE64 (Image, 32);
      Count := U64 (LE16 (Image, 56));
      if Count = 0 or else Count > 64 or else not Within (PH, Count * 56)
      then return; end if;
      Plan.Entry_Point := LE64 (Image, 24);
      for I in 0 .. Natural (Count) - 1 loop
         P := PH + U64 (I) * 56;
         Kind := U64 (LE32 (Image, Natural (P)));
         Flags := U64 (LE32 (Image, Natural (P + 4)));
         File_Offset := LE64 (Image, Natural (P + 8));
         VA := LE64 (Image, Natural (P + 16));
         FS := LE64 (Image, Natural (P + 32));
         MS := LE64 (Image, Natural (P + 40));
         Align := LE64 (Image, Natural (P + 48));
         if Kind = 3 then Result := Unsupported; return; end if;
         if Kind = 2 then
            if not Within (File_Offset, FS) or else FS mod 16 /= 0 then return; end if;
            Plan.Dynamic_Offset := VA;
            Plan.Dynamic_Size := FS;
         elsif Kind = 1 and then MS /= 0 then
            if Plan.Count = Max_Segments or else FS > MS or else
              not Within (File_Offset, FS) or else not Fits (VA, MS) or else
              VA + MS > 64 * 1024 * 1024 or else
              (Align > 1 and then (not Power_Of_Two (Align) or else
                VA mod Align /= File_Offset mod Align)) or else
              (Flags and 3) = 3 or else (Flags and 4) = 0
            then return; end if;
            for J in 1 .. Plan.Count loop
               if VA < Plan.Segments (J).Virtual_Base +
                 Plan.Segments (J).Memory_Size and then
                 Plan.Segments (J).Virtual_Base < VA + MS
               then return; end if;
            end loop;
            Plan.Count := Plan.Count + 1;
            Plan.Segments (Plan.Count) := (File_Offset, VA, FS, MS, Align, U32 (Flags));
            Plan.Span := U64'Max (Plan.Span, VA + MS);
            if (Flags and 1) /= 0 and then Plan.Entry_Point >= VA and then
              Plan.Entry_Point - VA < FS
            then Entry_Found := True; end if;
         end if;
      end loop;
      if not Entry_Found or else Plan.Count = 0 or else
        Plan.Dynamic_Offset > Plan.Span or else
        Plan.Dynamic_Size > Plan.Span - Plan.Dynamic_Offset
      then return; end if;
      Result := Success;
   end Validate;
end AxiomOS.Boot.ELF;
