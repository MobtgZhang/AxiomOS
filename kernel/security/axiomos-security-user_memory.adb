package body AxiomOS.Security.User_Memory is
   use type U64;
   procedure Translate (Space : Memory.Virtual.Address_Space; Address, Length : U64;
                         Write : Boolean; Physical : out U64; Result : out Status) is
   begin
      Physical := 0;
      Result := Permission_Denied;
      if not Memory.Virtual.Check_User (Space, Address, Length, Write) then return; end if;
      for M of Space.Entries loop
         if M.Active and then Address >= M.Virtual_Base and then
           Address - M.Virtual_Base < M.Length and then
           Length <= M.Length - (Address - M.Virtual_Base)
         then
            Physical := M.Physical_Base + Address - M.Virtual_Base;
            Result := Success;
            return;
         end if;
      end loop;
      Result := Invalid_Argument;
   end Translate;
end AxiomOS.Security.User_Memory;
