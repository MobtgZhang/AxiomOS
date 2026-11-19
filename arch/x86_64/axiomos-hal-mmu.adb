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
      if not Aligned (Virtual_Base, 4096) or else not Aligned (Physical_Base, 4096)
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
