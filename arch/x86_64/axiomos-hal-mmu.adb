with Interfaces;
with AxiomOS.X86;
with AxiomOS.Raw;
package body AxiomOS.HAL.MMU is
   use type U64;
   NX : constant U64 := 16#8000_0000_0000_0000#;
   Mask : constant U64 := 16#000F_FFFF_FFFF_F000#;
   procedure Enable_NX with Import, Convention => C, External_Name => "axiom_enable_nx";
   procedure New_Table (Pages : in out Memory.Physical.Allocator;
                         Base : out U64; Result : out Status) is
   begin
      Memory.Physical.Allocate (Pages, 1, 4096, Memory.Physical.Page_Table, Base, Result);
      if Result = Success then Raw.Zero (Base, 4096); end if;
   end New_Table;
   procedure Create (Pages : in out Memory.Physical.Allocator;
                     Info : Boot.Protocol.Boot_Info; Root : out U64;
                     Result : out Status) is
      PDPT, PD : U64;
   begin
      Root := 0;
      if Info.Kernel_Base >= 2 ** 32 or else Info.Stack_Base >= 2 ** 32 then
         Result := Unsupported; return;
      end if;
      New_Table (Pages, Root, Result);
      if Result /= Success then
         Destroy (Pages, Root); Root := 0; return;
      end if;
      New_Table (Pages, PDPT, Result);
      if Result /= Success then
         Destroy (Pages, Root); Root := 0; return;
      end if;
      Raw.Store64 (Root, PDPT or 7);
      for G in 0 .. 3 loop
         New_Table (Pages, PD, Result);
         if Result /= Success then
            Destroy (Pages, Root); Root := 0; return;
         end if;
         Raw.Store64 (PDPT + U64 (G) * 8, PD or 7);
         for I in 0 .. 511 loop
            -- Supervisor identity aperture. Split on demand for kernel W^X
            -- and isolated user pages. NX is enabled before activation.
            Raw.Store64 (PD + U64 (I) * 8,
                         U64 (G) * 2 ** 30 + U64 (I) * 2 ** 21 + 16#83# + NX);
         end loop;
      end loop;
      Result := Success;
   end Create;
   procedure Map_Page (Pages : in out Memory.Physical.Allocator;
                       Root, Virtual_Base, Physical_Base : U64;
                       Rights : Memory.Virtual.Permissions; Result : out Status) is
      Table : U64 := Root;
      Slot, Descriptor, Next, Flags, Large_Base : U64;
      Shift : Natural;
   begin
      Result := Invalid_Argument;
      if Root = 0 or else not Aligned (Root, Page_Size) or else
        Physical_Base >= 2 ** 48 or else Virtual_Base >= 2 ** 48 or else
        not Aligned (Virtual_Base, 4096) or else not Aligned (Physical_Base, 4096)
        or else not Rights.Readable or else (Rights.Writable and Rights.Executable)
        or else (Rights.Device and Rights.Executable) or else
        (Rights.User and Virtual_Base > Memory.Virtual.User_Limit)
      then return; end if;
      for Level in reverse 1 .. 3 loop
         Shift := 12 + 9 * Level;
         Slot := Table + (Interfaces.Shift_Right (Virtual_Base, Shift) and 511) * 8;
         Descriptor := Raw.Load64 (Slot);
         if (Descriptor and 1) = 0 then
            New_Table (Pages, Next, Result);
            if Result /= Success then return; end if;
            Raw.Store64 (Slot, Next or 7);
         elsif Level = 1 and then (Descriptor and 16#80#) /= 0 then
            New_Table (Pages, Next, Result);
            if Result /= Success then return; end if;
            Large_Base := Descriptor and 16#000F_FFFF_FFE0_0000#;
            Flags := Descriptor and (NX or 16#17F#);
            for I in 0 .. 511 loop
               Raw.Store64 (Next + U64 (I) * 8, (Large_Base + U64 (I) * 4096) or Flags);
            end loop;
            Raw.Store64 (Slot, Next or 7);
         else Next := Descriptor and Mask;
         end if;
         Table := Next;
      end loop;
      Flags := 1;
      if Rights.Writable then Flags := Flags or 2; end if;
      if Rights.User then Flags := Flags or 4; end if;
      if Rights.Device then Flags := Flags or 16#18#; end if;
      if not Rights.Executable then Flags := Flags or NX; end if;
      Raw.Store64 (Table + (Virtual_Base / 4096 mod 512) * 8, Physical_Base or Flags);
      Result := Success;
   end Map_Page;
   procedure Query_Page (Root, Virtual_Base : U64; Physical_Base : out U64;
                         Rights : out Memory.Virtual.Permissions; Result : out Status) is
      Table : U64 := Root;
      D, Span : U64;
   begin
      Physical_Base := 0; Rights := (others => False); Result := Invalid_Argument;
      if Root = 0 or else not Aligned (Root, Page_Size) or else Virtual_Base >= 2 ** 48 then return; end if;
      for Level in reverse 0 .. 3 loop
         D := Raw.Load64 (Table + (Interfaces.Shift_Right (Virtual_Base, 12 + Level * 9) and 511) * 8);
         if (D and 1) = 0 then Result := Not_Found; return; end if;
         if Level = 0 or else (D and 16#80#) /= 0 then
            Span := 2 ** (12 + Level * 9);
            Physical_Base := (D and Mask) / Span * Span + Virtual_Base mod Span;
            Rights.Readable := True; Rights.User := (D and 4) /= 0;
            Rights.Writable := (D and 2) /= 0; Rights.Executable := (D and NX) = 0;
            Rights.Device := (D and 16#18#) /= 0; Result := Success; return;
         end if;
         Table := D and Mask;
      end loop;
      Result := Not_Found;
   end Query_Page;

   procedure Unmap_Page (Pages : in out Memory.Physical.Allocator;
                         Root, Virtual_Base : U64; Result : out Status) is
      type Path is array (Natural range 0 .. 3) of U64;
      Tables, Slots : Path := (others => 0);
      Table : U64 := Root;
      D : U64;
      Lowest : Natural := 3;
      Empty : Boolean;
      S : Status;
   begin
      Result := Invalid_Argument;
      if Root = 0 or else not Aligned (Root, Page_Size) or else
        not Aligned (Virtual_Base, Page_Size) or else Virtual_Base >= 2 ** 48 then return; end if;
      Result := Not_Found;
      for Level in reverse 0 .. 3 loop
         Lowest := Level; Tables (Level) := Table;
         Slots (Level) := Table + (Interfaces.Shift_Right (Virtual_Base, 12 + 9 * Level) and 511) * 8;
         D := Raw.Load64 (Slots (Level));
         exit when (D and 1) = 0;
         if Level = 0 or else (D and 16#80#) /= 0 then
            if Level /= 0 or else not ((D and 4) /= 0) then Result := Permission_Denied; return; end if;
            Raw.Store64 (Slots (Level), 0); Result := Success; exit;
         end if;
         Table := D and Mask;
      end loop;
      -- Also prune a partially built path after a failed Map_Page allocation.
      for Level in Lowest .. 2 loop
         Empty := True;
         for I in 0 .. 511 loop
            if Raw.Load64 (Tables (Level) + U64 (I) * 8) /= 0 then Empty := False; exit; end if;
         end loop;
         exit when not Empty;
         Raw.Store64 (Slots (Level + 1), 0);
         Memory.Physical.Release (Pages, Tables (Level), 1, S);
      end loop;
   end Unmap_Page;

   procedure Protect_Page (Pages : in out Memory.Physical.Allocator;
                           Root, Virtual_Base : U64;
                           Rights : Memory.Virtual.Permissions; Result : out Status) is
      PA : U64;
      Previous : Memory.Virtual.Permissions;
   begin
      Result := Invalid_Argument;
      if not Aligned (Virtual_Base, Page_Size) or else not Rights.User then return; end if;
      Query_Page (Root, Virtual_Base, PA, Previous, Result);
      if Result /= Success then return; end if;
      if not Previous.User then Result := Permission_Denied; return; end if;
      Map_Page (Pages, Root, Virtual_Base, PA, Rights, Result);
   end Protect_Page;

   procedure Activate (Root : U64) is
   begin
      Enable_NX;
      X86.Write_CR3 (Root);
   end Activate;
   procedure Destroy (Pages : in out Memory.Physical.Allocator; Root : U64) is
      S : Status;
      procedure Walk (Table : U64; Level : Natural) is
         D : U64;
      begin
         if Level > 0 then
            for I in 0 .. 511 loop
               D := Raw.Load64 (Table + U64 (I) * 8);
               if (D and 1) /= 0 and then (D and 16#80#) = 0 then
                  Walk (D and Mask, Level - 1);
               end if;
            end loop;
         end if;
         Memory.Physical.Release (Pages, Table, 1, S);
      end Walk;
   begin
      if Root /= 0 then Walk (Root, 3); end if;
   end Destroy;
end AxiomOS.HAL.MMU;
