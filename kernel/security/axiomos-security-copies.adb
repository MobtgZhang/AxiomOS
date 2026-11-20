package body AxiomOS.Security.Copies is
   use type U64;
   procedure Transfer (Space : Memory.Virtual.Address_Space; Address, Buffer, Length : U64;
                       To_User : Boolean; Result : out Status) is
      Cursor : U64 := Address;
      Done, Count : U64 := 0;
   begin
      Result := Success;
      if Length = 0 then return; end if;
      Result := Permission_Denied;
      if not Memory.Virtual.Check_User (Space, Address, Length, To_User) then return; end if;
      while Done < Length loop
         for M of Space.Entries loop
            if M.Active and then Cursor >= M.Virtual_Base and then Cursor - M.Virtual_Base < M.Length then
               Count := U64'Min (Length - Done, M.Length - (Cursor - M.Virtual_Base));
               if To_User then
                  Move (M.Physical_Base + Cursor - M.Virtual_Base, Buffer + Done, Count);
               else
                  Move (Buffer + Done, M.Physical_Base + Cursor - M.Virtual_Base, Count);
               end if;
               Done := Done + Count; Cursor := Cursor + Count; exit;
            end if;
         end loop;
      end loop;
      Result := Success;
   end Transfer;
   procedure Read (Space : Memory.Virtual.Address_Space; Address : U64;
                   Buffer : out Bytes; Result : out Status) is
   begin
      Buffer := (others => 0);
      Transfer (Space, Address, Number (Buffer'Address), U64 (Buffer'Length), False, Result);
   end Read;
   procedure Write (Space : Memory.Virtual.Address_Space; Address : U64;
                    Buffer : Bytes; Result : out Status) is
   begin
      Transfer (Space, Address, Number (Buffer'Address), U64 (Buffer'Length), True, Result);
   end Write;
end AxiomOS.Security.Copies;
