with Interfaces;
with AxiomOS.Raw;
package body AxiomOS.HAL.MMU is
   use type U64;
   Mask : constant U64 := 16#0000_FFFF_FFFF_F000#;
   NX : constant U64 := 16#4000_0000_0000_0000#;
   procedure Switch_Root (Root : U64)
     with Import, Convention => C, External_Name => "axiom_switch_root";
   procedure New_Table (Pages : in out Memory.Physical.Allocator;
                         Base : out U64; Result : out Status) is
   begin
      Memory.Physical.Allocate (Pages, 1, 4096, Memory.Physical.Page_Table, Base, Result);
      if Result = Success then Raw.Zero (Base, 4096); end if;
   end New_Table;
   procedure Create (Pages : in out Memory.Physical.Allocator;
                     Info : Boot.Protocol.Boot_Info; Root : out U64;
                     Result : out Status) is
      L1, L0, P, Flags : U64;
   begin
      Root := 0;
      if Info.Kernel_Base >= 2 ** 32 then Result := Unsupported; return; end if;
      New_Table (Pages, Root, Result);
      if Result /= Success then
         Destroy (Pages, Root); Root := 0; return;
      end if;
      for G in 0 .. 3 loop
         New_Table (Pages, L1, Result);
         if Result /= Success then
            Destroy (Pages, Root); Root := 0; return;
         end if;
         Raw.Store64 (Root + U64 (G) * 8, L1);
         for I in 0 .. 511 loop
            New_Table (Pages, L0, Result);
            if Result /= Success then
               Destroy (Pages, Root); Root := 0; return;
            end if;
            Raw.Store64 (L1 + U64 (I) * 8, L0);
            for J in 0 .. 511 loop
               P := U64 (G) * 2 ** 30 + U64 (I) * 2 ** 21 + U64 (J) * 4096;
               Flags := NX or 16#13#; -- Valid, dirty, PLV0, coherent cached
               if P >= 16#10000000# and P < 16#80000000# then
                  Flags := NX or 3; -- MMIO aperture, strongly ordered
               end if;
               Raw.Store64 (L0 + U64 (J) * 8, P or Flags);
            end loop;
         end loop;
      end loop;
      Result := Success;
   end Create;
   procedure Map_Page (Pages : in out Memory.Physical.Allocator;
                       Root, Virtual_Base, Physical_Base : U64;
                       Rights : Memory.Virtual.Permissions; Result : out Status) is
      Table : U64 := Root;
      Slot, Next, Flags : U64;
   begin
      Result := Invalid_Argument;
      if Root = 0 or else not Aligned (Root, Page_Size) or else
        Physical_Base >= 2 ** 48 or else Virtual_Base >= 2 ** 38 or else
        not Aligned (Virtual_Base, 4096) or else not Aligned (Physical_Base, 4096)
        or else not Rights.Readable or else (Rights.Writable and Rights.Executable)
        or else (Rights.Device and Rights.Executable) or else Virtual_Base >= 2 ** 38
      then return; end if;
      for Level in reverse 1 .. 2 loop
         Slot := Table + (Interfaces.Shift_Right (Virtual_Base, 12 + 9 * Level) and 511) * 8;
         Next := Raw.Load64 (Slot) and Mask;
         if Next = 0 then
            New_Table (Pages, Next, Result);
            if Result /= Success then return; end if;
            Raw.Store64 (Slot, Next);
         end if;
         Table := Next;
      end loop;
      Flags := 17;
      if Rights.Writable then Flags := Flags or 2; end if;
      if Rights.User then Flags := Flags or 12; end if;
      if not Rights.Executable then Flags := Flags or NX; end if;
      if Rights.Device then Flags := Flags and not U64 (48); end if;
      Raw.Store64 (Table + (Virtual_Base / 4096 mod 512) * 8, Physical_Base or Flags);
      Result := Success;
   end Map_Page;
   procedure Query_Page (Root, Virtual_Base : U64; Physical_Base : out U64;
                         Rights : out Memory.Virtual.Permissions; Result : out Status) is
      Table : U64 := Root;
      D, Span : U64;
   begin
      Physical_Base := 0; Rights := (others => False); Result := Invalid_Argument;
      if Root = 0 or else not Aligned (Root, Page_Size) or else Virtual_Base >= 2 ** 38 then return; end if;
      for Level in reverse 0 .. 2 loop
         D := Raw.Load64 (Table + (Interfaces.Shift_Right (Virtual_Base, 12 + Level * 9) and 511) * 8);
         if D = 0 then Result := Not_Found; return; end if;
         if Level = 0 then
            Span := 2 ** (12 + Level * 9);
            Physical_Base := (D and Mask) / Span * Span + Virtual_Base mod Span;
            Rights.Readable := True; Rights.User := (D and 12) = 12;
            Rights.Writable := (D and 2) /= 0; Rights.Executable := (D and NX) = 0;
            Rights.Device := (D and 48) = 0; Result := Success; return;
         end if;
         Table := D and Mask;
      end loop;
      Result := Not_Found;
   end Query_Page;

   procedure Unmap_Page (Pages : in out Memory.Physical.Allocator;
                         Root, Virtual_Base : U64; Result : out Status) is
      type Path is array (Natural range 0 .. 2) of U64;
      Tables, Slots : Path := (others => 0);
      Table : U64 := Root;
      D : U64;
      Lowest : Natural := 2;
      Empty : Boolean;
      S : Status;
   begin
      Result := Invalid_Argument;
      if Root = 0 or else not Aligned (Root, Page_Size) or else
        not Aligned (Virtual_Base, Page_Size) or else Virtual_Base >= 2 ** 38 then return; end if;
      Result := Not_Found;
      for Level in reverse 0 .. 2 loop
         Lowest := Level; Tables (Level) := Table;
         Slots (Level) := Table + (Interfaces.Shift_Right (Virtual_Base, 12 + 9 * Level) and 511) * 8;
         D := Raw.Load64 (Slots (Level));
         exit when D = 0;
         if Level = 0 then
            if Level /= 0 or else not ((D and 12) = 12) then Result := Permission_Denied; return; end if;
            Raw.Store64 (Slots (Level), 0); Result := Success; exit;
         end if;
         Table := D and Mask;
      end loop;
      -- Also prune a partially built path after a failed Map_Page allocation.
      for Level in Lowest .. 1 loop
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
   begin Switch_Root (Root); end Activate;
   procedure Destroy (Pages : in out Memory.Physical.Allocator; Root : U64) is
      S : Status;
      procedure Walk (Table : U64; Level : Natural) is
         D : U64;
      begin
         if Level > 0 then
            for I in 0 .. 511 loop
               D := Raw.Load64 (Table + U64 (I) * 8) and Mask;
               if D /= 0 then Walk (D, Level - 1); end if;
            end loop;
         end if;
         Memory.Physical.Release (Pages, Table, 1, S);
      end Walk;
   begin
      if Root /= 0 then Walk (Root, 2); end if;
   end Destroy;
end AxiomOS.HAL.MMU;
