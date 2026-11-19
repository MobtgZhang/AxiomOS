with Interfaces;
package body AxiomOS.Memory.Heap is
   use type U64;
   procedure Initialize (State : in out Allocator) is
   begin
      for P of State.Pools loop P := (others => <>); end loop;
   end Initialize;
   procedure Allocate (State : in out Allocator; Pages : in out Physical.Allocator;
                       Length, Alignment : U64; Address : out U64; Result : out Status) is
      Size : U64 := 32;
      Empty : Natural := 0;
      Page_Count, Slot : Natural;
      Mask, Base : U64;
      procedure Take (P : in out Slab) is
      begin
         for I in 0 .. 4096 / P.Slot_Size - 1 loop
            Mask := Interfaces.Shift_Left (U64 (1), I mod 64);
            if (P.Allocated (I / 64) and Mask) = 0 then
               P.Allocated (I / 64) := P.Allocated (I / 64) or Mask;
               P.Used := P.Used + 1; Address := P.Base + U64 (I * P.Slot_Size);
               Result := Success; return;
            end if;
         end loop;
         Result := Corrupt;
      end Take;
   begin
      Address := 0; Result := Invalid_Argument;
      if Length = 0 or else not Power_Of_Two (Alignment) or else Alignment > Page_Size or else
        Length > U64 (Physical.Max_Pages) * Page_Size then return; end if;
      while Size < U64' Max (Length, Alignment) and Size < Page_Size loop Size := Size * 2; end loop;
      for I in State.Pools'Range loop
         if State.Pools (I).Base = 0 then Empty := I;
         elsif Size <= 2048 and then State.Pools (I).Slot_Size = Natural (Size) and then
           State.Pools (I).Used < 4096 / Natural (Size) then Take (State.Pools (I)); return;
         end if;
      end loop;
      if Empty = 0 then Result := No_Space; return; end if;
      Page_Count := (if Size <= 2048 then 1 else Natural ((Length + Page_Size - 1) / Page_Size));
      Physical.Allocate (Pages, Page_Count, Page_Size, Physical.Kernel, Base, Result);
      if Result /= Success then return; end if;
      Slot := Empty; State.Pools (Slot) := (Base, 0, Page_Count, 1, (others => 0));
      if Size <= 2048 then
         State.Pools (Slot).Slot_Size := Natural (Size); State.Pools (Slot).Used := 0;
         Take (State.Pools (Slot));
      else Address := Base; Result := Success; end if;
   end Allocate;
   procedure Free (State : in out Allocator; Pages : in out Physical.Allocator;
                   Address : U64; Result : out Status) is
      Index : Natural;
      Mask : U64;
   begin
      Result := Invalid_Argument;
      if Address = 0 then return; end if;
      for P of State.Pools loop
         if P.Base /= 0 and then Address >= P.Base and then Address - P.Base < U64 (P.Pages) * Page_Size then
            if P.Slot_Size = 0 then
               if Address /= P.Base then return; end if;
            else
               if (Address - P.Base) mod U64 (P.Slot_Size) /= 0 then return; end if;
               Index := Natural ((Address - P.Base) / U64 (P.Slot_Size));
               Mask := Interfaces.Shift_Left (U64 (1), Index mod 64);
               if (P.Allocated (Index / 64) and Mask) = 0 then return; end if;
               P.Allocated (Index / 64) := P.Allocated (Index / 64) and not Mask;
               P.Used := P.Used - 1;
               if P.Used /= 0 then Result := Success; return; end if;
            end if;
            Physical.Release (Pages, P.Base, P.Pages, Result);
            if Result = Success then P := (others => <>); end if;
            return;
         end if;
      end loop;
   end Free;
end AxiomOS.Memory.Heap;
