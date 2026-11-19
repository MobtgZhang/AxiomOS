package body AxiomOS.VFS.Paths is
   procedure Normalize (Path : String; Output : out String;
                        Length : out Natural; Result : out Status) is
      N : Natural := 0;
      Start : Integer;
      Cursor : Integer := Path'First;
   begin
      Output := (others => Character'Val (0));
      Length := 0;
      Result := Invalid_Argument;
      if Path'Length = 0 or else Path (Cursor) /= '/' or else
        Output'Length = 0
      then return; end if;
      N := 1;
      Output (Output'First) := '/';
      while Cursor <= Path'Last loop
         if Path (Cursor) = '/' then
            Cursor := Cursor + 1;
         else
            Start := Cursor;
            while Cursor <= Path'Last and then Path (Cursor) /= '/' loop
               if Character'Pos (Path (Cursor)) < 32 or else
                 Path (Cursor) = Character'Val (127) or else Path (Cursor) = '\'
               then return; end if;
               Cursor := Cursor + 1;
            end loop;
            if Path (Start .. Cursor - 1) = ".." then
               Result := Permission_Denied;
               return;
            elsif Path (Start .. Cursor - 1) /= "." then
               if N > 1 then
                  if N = Output'Length then return; end if;
                  Output (Output'First + N) := '/';
                  N := N + 1;
               end if;
               if Cursor - Start > Output'Length - N then return; end if;
               Output (Output'First + N .. Output'First + N + Cursor - Start - 1)
                 := Path (Start .. Cursor - 1);
               N := N + Cursor - Start;
            end if;
         end if;
      end loop;
      Length := N;
      Result := Success;
   end Normalize;

end AxiomOS.VFS.Paths;
