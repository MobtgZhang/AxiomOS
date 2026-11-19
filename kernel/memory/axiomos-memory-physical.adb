package body AxiomOS.Memory.Physical is
   use type U64, U16;
   procedure Reset (State : in out Allocator) is
   begin
      State.Region_Count := 0;
      State.Total := 0;
      State.Available := 0;
      State.Metadata := (others => (Free, 0));
   end Reset;

   procedure Add_Region (State : in out Allocator; Base, Length : U64;
                         Result : out Status) is
      Pages : U64;
   begin
      Result := Invalid_Argument;
      if not Fits (Base, Length) or else Base = 0 or else
        not Aligned (Base, Page_Size) or else not Aligned (Length, Page_Size)
      then
         return;
      end if;
      for I in 1 .. State.Region_Count loop
         declare
            R : Region renames State.Regions (I);
         begin
            if Base < R.Base + U64 (R.Pages) * Page_Size and then
              R.Base < Base + Length
            then
               Result := Already_Exists;
               return;
            end if;
         end;
      end loop;
      Pages := Length / Page_Size;
      if State.Region_Count = Max_Regions or else
        Pages > U64 (Max_Pages - State.Total)
      then
         Result := No_Space;
         return;
      end if;
      State.Region_Count := State.Region_Count + 1;
      State.Regions (State.Region_Count) := (Base, Natural (Pages), State.Total);
      State.Total := State.Total + Natural (Pages);
      State.Available := State.Available + Natural (Pages);
      Result := Success;
   end Add_Region;

   procedure Allocate (State : in out Allocator; Count : Positive;
                       Alignment : U64; Kind : Owner;
                       Address : out U64; Result : out Status) is
      Run : Natural;
   begin
      Address := 0;
      Result := Invalid_Argument;
      if Kind = Free or else not Power_Of_Two (Alignment) or else
        Alignment < Page_Size
      then
         return;
      end if;
      Result := Out_Of_Memory;
      if Count > State.Available then
         return;
      end if;
      for I in 1 .. State.Region_Count loop
         declare
            R : Region renames State.Regions (I);
         begin
            Run := 0;
            for P in 0 .. R.Pages - 1 loop
               if State.Metadata (R.Offset + P).Kind /= Free then
                  Run := 0;
               elsif Run /= 0 or else Aligned
                 (R.Base + U64 (P) * Page_Size, Alignment)
               then
                  Run := Run + 1;
               end if;
               if Run = Count then
                  Address := R.Base + U64 (P + 1 - Count) * Page_Size;
                  for J in P + 1 - Count .. P loop
                     State.Metadata (R.Offset + J) := (Kind, 1);
                  end loop;
                  State.Available := State.Available - Count;
                  Result := Success;
                  return;
               end if;
            end loop;
         end;
      end loop;
   end Allocate;

   function Locate (State : Allocator; Address : U64; Count : Positive)
                    return Integer is
   begin
      if not Aligned (Address, Page_Size) then
         return -1;
      end if;
      for I in 1 .. State.Region_Count loop
         declare
            R : Region renames State.Regions (I);
         begin
            if Address >= R.Base and then
              (Address - R.Base) / Page_Size < U64 (R.Pages) and then
              U64 (Count) <= U64 (R.Pages) - (Address - R.Base) / Page_Size
            then
               return R.Offset + Natural ((Address - R.Base) / Page_Size);
            end if;
         end;
      end loop;
      return -1;
   end Locate;

   procedure Release (State : in out Allocator; Address : U64;
                      Count : Positive; Result : out Status) is
      First : constant Integer := Locate (State, Address, Count);
   begin
      Result := Invalid_Argument;
      if First < 0 then return; end if;
      for I in First .. First + Count - 1 loop
         if State.Metadata (I).Kind = Free or else
           State.Metadata (I).References = 0
         then
            return;
         end if;
      end loop;
      for I in First .. First + Count - 1 loop
         State.Metadata (I).References := State.Metadata (I).References - 1;
         if State.Metadata (I).References = 0 then
            State.Metadata (I).Kind := Free;
            State.Available := State.Available + 1;
         end if;
      end loop;
      Result := Success;
   end Release;

   procedure Retain (State : in out Allocator; Address : U64;
                     Result : out Status) is
      Index : constant Integer := Locate (State, Address, 1);
   begin
      Result := Invalid_Argument;
      if Index < 0 or else State.Metadata (Index).Kind = Free then return; end if;
      if State.Metadata (Index).References = U16'Last then
         Result := No_Space;
         return;
      end if;
      State.Metadata (Index).References := State.Metadata (Index).References + 1;
      Result := Success;
   end Retain;
end AxiomOS.Memory.Physical;
