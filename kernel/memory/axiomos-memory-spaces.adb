with AxiomOS.HAL.MMU;
with AxiomOS.Raw;
with AxiomOS.HAL.CPU;
package body AxiomOS.Memory.Spaces is
   use type U64;
   function Valid (Address, Length : U64) return Boolean is
     (Address >= User_First and then Address < User_End and then
      Length > 0 and then Length <= Max_Allocation and then Length <= User_End - Address and then
      Aligned (Address, Page_Size) and then Aligned (Length, Page_Size));
   function Allowed (Rights : Virtual.Permissions) return Boolean is
     (Rights.User and then Rights.Readable and then not Rights.Device and then
      not (Rights.Writable and Rights.Executable));
   function Find (Space : Virtual.Address_Space; Address, Length : U64) return Natural is
   begin
      for I in Space.Entries'Range loop
         if Space.Entries (I).Active and then Space.Entries (I).Virtual_Base = Address and then
           Space.Entries (I).Length = Length then return I; end if;
      end loop;
      return 0;
   end Find;
   procedure Allocate (Pages : in out Physical.Allocator;
                       Space : in out Virtual.Address_Space; Root : U64;
                       Address, Length : U64; Rights : Virtual.Permissions;
                       Result : out Status) is
      Base, Committed : U64 := 0;
      Done : Natural := 0;
      S : Status;
   begin
      Result := Invalid_Argument;
      if Root = 0 or else not Valid (Address, Length) or else not Allowed (Rights) then return; end if;
      for M of Space.Entries loop
         if M.Active and then M.Virtual_Base >= User_First and then M.Virtual_Base < User_End then
            Committed := Committed + M.Length;
         end if;
      end loop;
      if Committed > Max_Committed - Length then Result := No_Space; return; end if;
      Physical.Allocate (Pages, Positive (Length / Page_Size), Page_Size, Physical.Process, Base, Result);
      if Result /= Success then return; end if;
      Virtual.Map (Space, Address, Base, Length, Rights, Result);
      if Result /= Success then Physical.Release (Pages, Base, Positive (Length / Page_Size), S); return; end if;
      Raw.Zero (Base, Length);
      for I in 0 .. Natural (Length / Page_Size) - 1 loop
         HAL.MMU.Map_Page (Pages, Root, Address + U64 (I) * Page_Size,
                          Base + U64 (I) * Page_Size, Rights, Result);
         exit when Result /= Success;
         Done := Done + 1;
      end loop;
      if Result /= Success then
         -- Include the failed page to prune any intermediate tables created
         -- before the backend ran out of physical pages.
         for I in 0 .. Done loop
            HAL.MMU.Unmap_Page (Pages, Root, Address + U64 (I) * Page_Size, S);
         end loop;
         HAL.MMU.Activate (Root);
         Virtual.Unmap (Space, Address, Length, S);
         Physical.Release (Pages, Base, Positive (Length / Page_Size), S);
         return;
      end if;
      HAL.MMU.Activate (Root);
   end Allocate;
   procedure Release (Pages : in out Physical.Allocator;
                      Space : in out Virtual.Address_Space; Root : U64;
                      Address, Length : U64; Result : out Status) is
      Index : constant Natural := Find (Space, Address, Length);
      PA : U64;
      Rights : Virtual.Permissions;
      S : Status;
   begin
      Result := Invalid_Argument;
      if not Valid (Address, Length) or else Root = 0 then return; end if;
      Result := Not_Found;
      if Index = 0 then return; end if;
      -- Validate all leaves before modifying either hardware or ownership.
      for I in 0 .. Natural (Length / Page_Size) - 1 loop
         HAL.MMU.Query_Page (Root, Address + U64 (I) * Page_Size, PA, Rights, Result);
         if Result /= Success then return; end if;
         if not Rights.User or else PA /= Space.Entries (Index).Physical_Base + U64 (I) * Page_Size then
            Result := Corrupt; return;
         end if;
      end loop;
      for I in 0 .. Natural (Length / Page_Size) - 1 loop
         HAL.MMU.Unmap_Page (Pages, Root, Address + U64 (I) * Page_Size, Result);
         if Result /= Success then return; end if;
      end loop;
      HAL.MMU.Activate (Root);
      Physical.Release (Pages, Space.Entries (Index).Physical_Base, Positive (Length / Page_Size), Result);
      if Result /= Success then return; end if;
      Virtual.Unmap (Space, Address, Length, S);
      Result := S;
   end Release;
   procedure Protect (Pages : in out Physical.Allocator;
                      Space : in out Virtual.Address_Space; Root : U64;
                      Address, Length : U64; Rights : Virtual.Permissions;
                      Result : out Status) is
      Index : constant Natural := Find (Space, Address, Length);
      PA : U64;
      Previous : Virtual.Permissions;
   begin
      Result := Invalid_Argument;
      if not Valid (Address, Length) or else not Allowed (Rights) or else Root = 0 then return; end if;
      Result := Not_Found;
      if Index = 0 then return; end if;
      for I in 0 .. Natural (Length / Page_Size) - 1 loop
         HAL.MMU.Query_Page (Root, Address + U64 (I) * Page_Size, PA, Previous, Result);
         if Result /= Success then return; end if;
         if not Previous.User or else PA /= Space.Entries (Index).Physical_Base + U64 (I) * Page_Size then
            Result := Corrupt; return;
         end if;
      end loop;
      if Rights.Executable then
         -- All architecture instruction-cache maintenance remains in HAL.
         HAL.CPU.Sync_Code (Space.Entries (Index).Physical_Base, Length);
      end if;
      for I in 0 .. Natural (Length / Page_Size) - 1 loop
         HAL.MMU.Protect_Page (Pages, Root, Address + U64 (I) * Page_Size, Rights, Result);
         if Result /= Success then return; end if;
      end loop;
      Space.Entries (Index).Access_Rights := Rights;
      HAL.MMU.Activate (Root);
      Result := Success;
   end Protect;
end AxiomOS.Memory.Spaces;
