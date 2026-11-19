with AxiomOS.Boot.ELF;
with AxiomOS.Firmware.UEFI;
with AxiomOS.Raw;
with AxiomOS.HAL.CPU;
with AxiomOS.Architecture;
package body AxiomOS.Boot.Images is
   use type U64;
   procedure Load_Kernel (File_Base, File_Size : U64;
                          Base, Size, Entry_Point : out U64;
                          Result : out Status) is
      Image : Bytes (0 .. Natural (File_Size) - 1)
        with Import, Address => Raw.Address (File_Base);
      Plan : ELF.Layout;
      S : U64;
      Rela, Rela_Size, Rela_Entry, Tag, Value, Target, Info, Addend : U64 := 0;
      Dynamic_Terminated : Boolean := False;
   begin
      Base := 0; Size := 0; Entry_Point := 0;
      ELF.Validate (Image, Architecture.ELF_Machine, Plan, Result);
      if Result /= Success then return; end if;
      Size := ((Plan.Span + Page_Size - 1) / Page_Size) * Page_Size;
      S := Firmware.UEFI.Allocate_Pages (Size / Page_Size, Base, Executable => True);
      if S /= 0 then Result := Out_Of_Memory; return; end if;
      Raw.Zero (Base, Size);
      for I in 1 .. Plan.Count loop
         declare M : ELF.Segment renames Plan.Segments (I);
         begin Raw.Copy (Base + M.Virtual_Base, File_Base + M.Offset, M.File_Size); end;
      end loop;
      if Plan.Dynamic_Size > 0 then
         for I in 0 .. Plan.Dynamic_Size / 16 - 1 loop
            Tag := Raw.Load64 (Base + Plan.Dynamic_Offset + I * 16);
            Value := Raw.Load64 (Base + Plan.Dynamic_Offset + I * 16 + 8);
            case Tag is
               when 0 => Dynamic_Terminated := True; exit;
               when 7 => Rela := Value;
               when 8 => Rela_Size := Value;
               when 9 => Rela_Entry := Value;
               when 1 | 17 | 18 | 19 | 22 | 23 | 35 | 36 | 37 =>
                  Result := Unsupported; return;
               when others => null;
            end case;
         end loop;
         if not Dynamic_Terminated then Result := Corrupt; return; end if;
      end if;
      if Rela_Size > 0 then
         if Rela_Entry /= 24 or else Rela_Size mod 24 /= 0 or else
           Rela > Plan.Span or else Rela_Size > Plan.Span - Rela
         then Result := Corrupt; return; end if;
         for I in 0 .. Rela_Size / 24 - 1 loop
            Target := Raw.Load64 (Base + Rela + I * 24);
            Info := Raw.Load64 (Base + Rela + I * 24 + 8);
            Addend := Raw.Load64 (Base + Rela + I * 24 + 16);
            if Info /= Architecture.Relative_Relocation or else
              Target > Plan.Span - 8 or else Addend > Size
            then Result := Corrupt; return; end if;
            Raw.Store64 (Base + Target, Base + Addend);
         end loop;
      end if;
      HAL.CPU.Sync_Code (Base, Size);
      Entry_Point := Base + Plan.Entry_Point;
      Result := Success;
   end Load_Kernel;
end AxiomOS.Boot.Images;
