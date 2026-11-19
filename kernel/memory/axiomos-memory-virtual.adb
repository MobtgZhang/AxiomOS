package body AxiomOS.Memory.Virtual is
   use type U64;
   function Valid_Range (Base, Length : U64; User : Boolean) return Boolean is
     (Base /= 0 and then Fits (Base, Length) and then
      (not User or else (Base <= User_Limit and then
                          Length - 1 <= User_Limit - Base)));

   procedure Map (Space : in out Address_Space; Virtual_Base, Physical_Base,
                  Length : U64; Rights : Permissions; Result : out Status) is
      Slot : Natural := 0;
   begin
      Result := Invalid_Argument;
      if not Valid_Range (Virtual_Base, Length, Rights.User) or else
        not Fits (Physical_Base, Length) or else
        not Aligned (Virtual_Base, Page_Size) or else
        not Aligned (Physical_Base, Page_Size) or else
        not Aligned (Length, Page_Size) or else not Rights.Readable or else
        (Rights.Writable and Rights.Executable) or else
        (Rights.Device and Rights.Executable)
      then
         return;
      end if;
      for I in Space.Entries'Range loop
         declare
            M : Mapping renames Space.Entries (I);
         begin
            if M.Active and then Virtual_Base <= M.Virtual_Base + M.Length - 1
              and then M.Virtual_Base <= Virtual_Base + Length - 1
            then
               Result := Already_Exists;
               return;
            elsif not M.Active and Slot = 0 then
               Slot := I;
            end if;
         end;
      end loop;
      if Slot = 0 then Result := No_Space; return; end if;
      Space.Entries (Slot) :=
        (Virtual_Base, Physical_Base, Length, Rights, True);
      Result := Success;
   end Map;

   procedure Unmap (Space : in out Address_Space; Virtual_Base, Length : U64;
                    Result : out Status) is
   begin
      Result := Not_Found;
      for M of Space.Entries loop
         if M.Active and then M.Virtual_Base = Virtual_Base and then
           M.Length = Length
         then
            M.Active := False;
            Result := Success;
            return;
         end if;
      end loop;
   end Unmap;

   function Check_User (Space : Address_Space; Address, Length : U64;
                        Write : Boolean := False) return Boolean is
      Cursor, Remaining, Step : U64;
      Found : Boolean;
   begin
      if not Valid_Range (Address, Length, True) then return False; end if;
      Cursor := Address;
      Remaining := Length;
      while Remaining > 0 loop
         Found := False;
         for M of Space.Entries loop
            if M.Active and then M.Access_Rights.User and then
              M.Access_Rights.Readable and then
              (not Write or else M.Access_Rights.Writable) and then
              Cursor >= M.Virtual_Base and then
              Cursor - M.Virtual_Base < M.Length
            then
               Step := U64'Min (Remaining, M.Length - (Cursor - M.Virtual_Base));
               Remaining := Remaining - Step;
               if Remaining > 0 then Cursor := Cursor + Step; end if;
               Found := True;
               exit;
            end if;
         end loop;
         if not Found then return False; end if;
      end loop;
      return True;
   end Check_User;
end AxiomOS.Memory.Virtual;
