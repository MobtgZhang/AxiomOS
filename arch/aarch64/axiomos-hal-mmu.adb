with Interfaces;
with AxiomOS.Raw;
package body AxiomOS.HAL.MMU is
   use type U64;
   Mask : constant U64 := 16#0000_FFFF_FFFF_F000#;
   XN : constant U64 := 16#0060_0000_0000_0000#;
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
      L1, L2, Flags : U64;
   begin
      Root := 0;
      if Info.Kernel_Base >= 2 ** 32 then Result := Unsupported; return; end if;
      New_Table (Pages, Root, Result);
      if Result /= Success then
         Destroy (Pages, Root); Root := 0; return;
      end if;
      New_Table (Pages, L1, Result);
      if Result /= Success then
         Destroy (Pages, Root); Root := 0; return;
      end if;
      Raw.Store64 (Root, L1 or 3);
      for G in 0 .. 3 loop
         New_Table (Pages, L2, Result);
         if Result /= Success then
            Destroy (Pages, Root); Root := 0; return;
         end if;
         Raw.Store64 (L1 + U64 (G) * 8, L2 or 3);
         Flags := XN or 16#701#; -- AF, inner shareable, privileged RW
         if G = 0 then Flags := XN or 16#405#; end if; -- Device-nGnRnE
         for I in 0 .. 511 loop
            Raw.Store64 (L2 + U64 (I) * 8,
                         (U64 (G) * 2 ** 30 + U64 (I) * 2 ** 21) or Flags);
         end loop;
      end loop;
      Result := Success;
   end Create;
   procedure Map_Page (Pages : in out Memory.Physical.Allocator;
                       Root, Virtual_Base, Physical_Base : U64;
                       Rights : Memory.Virtual.Permissions; Result : out Status) is
      Table : U64 := Root;
      Slot, D, Next, Flags, Large_Base : U64;
   begin
      Result := Invalid_Argument;
      if not Aligned (Virtual_Base, 4096) or else not Aligned (Physical_Base, 4096)
        or else not Rights.Readable or else (Rights.Writable and Rights.Executable)
        or else (Rights.Device and Rights.Executable) or else Virtual_Base >= 2 ** 48
      then return; end if;
      for Level in reverse 1 .. 3 loop
         Slot := Table + (Interfaces.Shift_Right (Virtual_Base, 12 + 9 * Level) and 511) * 8;
         D := Raw.Load64 (Slot);
         if (D and 1) = 0 then
            New_Table (Pages, Next, Result);
            if Result /= Success then return; end if;
            Raw.Store64 (Slot, Next or 3);
         elsif Level = 1 and then (D and 2) = 0 then
            New_Table (Pages, Next, Result);
            if Result /= Success then return; end if;
            Large_Base := D and 16#0000_FFFF_FFE0_0000#;
            Flags := (D and not Mask) or 2;
            for I in 0 .. 511 loop
               Raw.Store64 (Next + U64 (I) * 8, (Large_Base + U64 (I) * 4096) or Flags);
            end loop;
            Raw.Store64 (Slot, Next or 3);
         else Next := D and Mask;
         end if;
         Table := Next;
      end loop;
      Flags := 16#703#;
      if not Rights.Writable then Flags := Flags or 128; end if;
      if Rights.User then Flags := Flags or 64 or 16#0020_0000_0000_0000#;
      else Flags := Flags or 16#0040_0000_0000_0000#; end if;
      if not Rights.Executable then Flags := Flags or XN; end if;
      if Rights.Device then Flags := (Flags and not U64 (16#300#)) or 4; end if;
      Raw.Store64 (Table + (Virtual_Base / 4096 mod 512) * 8, Physical_Base or Flags);
      Result := Success;
   end Map_Page;
   procedure Activate (Root : U64) is
   begin Switch_Root (Root); end Activate;
   procedure Destroy (Pages : in out Memory.Physical.Allocator; Root : U64) is
      S : Status;
      procedure Walk (Table : U64; Level : Natural) is
         D : U64;
      begin
         if Level > 0 then
            for I in 0 .. 511 loop
               D := Raw.Load64 (Table + U64 (I) * 8);
               if (D and 3) = 3 then Walk (D and Mask, Level - 1); end if;
            end loop;
         end if;
         Memory.Physical.Release (Pages, Table, 1, S);
      end Walk;
   begin
      if Root /= 0 then Walk (Root, 3); end if;
   end Destroy;
end AxiomOS.HAL.MMU;
