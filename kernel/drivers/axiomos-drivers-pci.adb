with AxiomOS.Firmware.ACPI.Tables;
with AxiomOS.Raw;
package body AxiomOS.Drivers.PCI is
   use type U8, U16, U32, U64;
   procedure Find_Virtio_Block (Info : Boot.Protocol.Boot_Info;
                                Config, Common, Notify, Device_Config : out U64;
                                Multiplier : out U32; Result : out Status) is
      MCFG, Base, P, Cap, BAR, Address, Offset : U64;
      First, Last, Kind, Index : U8;
      Size : U64;
   begin
      Config := 0; Common := 0; Notify := 0; Device_Config := 0; Multiplier := 0;
      Firmware.ACPI.Tables.Find (Info.ACPI, 16#4746434D#, MCFG, Result);
      if Result /= Success then return; end if;
      Result := Not_Found;
      if Raw.Load32 (MCFG + 4) < 60 then Result := Corrupt; return; end if;
      Base := Raw.Load64 (MCFG + 44); First := Raw.Load8 (MCFG + 54); Last := Raw.Load8 (MCFG + 55);
      if Last < First or else Base = 0 then Result := Corrupt; return; end if;
      -- The supported QEMU boards expose all root devices on the first bus.
      for D in 0 .. 31 loop
         P := Base + U64 (D) * 32768;
         if Raw.Load16 (P) = 16#1AF4# and then Raw.Load16 (P + 2) = 16#1042# then
            Config := P; exit;
         end if;
      end loop;
      if Config = 0 then return; end if;
      Cap := U64 (Raw.Load8 (Config + 16#34#));
      for N in 1 .. 48 loop
         exit when Cap = 0;
         if Cap < 64 or else Cap > 236 or else Cap mod 4 /= 0 then Result := Corrupt; return; end if;
         P := Config + Cap;
         if Raw.Load8 (P) = 9 and then Raw.Load8 (P + 2) >= 16 then
            Kind := Raw.Load8 (P + 3); Index := Raw.Load8 (P + 4);
            if Kind in 1 | 2 | 4 then
            if Index > 5 then Result := Corrupt; return; end if;
            BAR := U64 (Raw.Load32 (Config + 16 + U64 (Index) * 4));
            if (BAR and 1) /= 0 then Result := Unsupported; return; end if;
            Address := BAR and 16#FFFF_FFF0#;
            if (BAR and 6) = 4 then
               if Index = 5 then Result := Corrupt; return; end if;
               Address := Address + U64 (Raw.Load32 (Config + 20 + U64 (Index) * 4)) * 2 ** 32;
            end if;
            Offset := U64 (Raw.Load32 (P + 8)); Size := U64 (Raw.Load32 (P + 12));
            if (Kind = 1 and then (Size < 56 or Offset mod 4 /= 0)) or else
              (Kind = 2 and then (Size < 2 or Offset mod 2 /= 0)) or else
              (Kind = 4 and then (Size < 8 or Offset mod 8 /= 0)) then Result := Corrupt; return; end if;
            if Address = 0 or else not Fits (Address, Offset + Size) then
               Result := Corrupt; return;
            end if;
            case Kind is
               when 1 => Common := Address + Offset;
               when 2 =>
                  if Raw.Load8 (P + 2) < 20 then Result := Corrupt; return; end if;
                  Notify := Address + Offset; Multiplier := Raw.Load32 (P + 16);
               when 4 => Device_Config := Address + Offset;
               when others => null;
            end case;
            end if;
         end if;
         Cap := U64 (Raw.Load8 (P + 1));
      end loop;
      if Common = 0 or Notify = 0 or Device_Config = 0 then Result := Unsupported; return; end if;
      Raw.Store16 (Config + 4, Raw.Load16 (Config + 4) or 6);
      Result := Success;
   end Find_Virtio_Block;
end AxiomOS.Drivers.PCI;
