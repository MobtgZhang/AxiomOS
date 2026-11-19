with AxiomOS.Raw;
package body AxiomOS.Memory.Bootstrap is
   use type U32, U64;
   procedure Import_Map (Info : Boot.Protocol.Boot_Info;
                         Pages : in out Physical.Allocator; Result : out Status) is
      Cursor, Base, Count, Available : U64;
   begin
      Result := Invalid_Argument;
      if not Boot.Protocol.Valid (Info) then return; end if;
      Physical.Reset (Pages);
      for I in 0 .. Info.Memory_Map_Size / Info.Descriptor_Size - 1 loop
         Cursor := Info.Memory_Map + I * Info.Descriptor_Size;
         -- Import ONLY EfiConventionalMemory. Loader, runtime, ACPI, MMIO,
         -- handoff buffers, kernel and stack therefore remain reserved.
         if Raw.Load32 (Cursor) = 7 then
            Base := Raw.Load64 (Cursor + 8);
            Count := Raw.Load64 (Cursor + 24);
            if Base = 0 and then Count > 0 then Base := Page_Size; Count := Count - 1; end if;
            Available := U64 (Physical.Max_Pages - Pages.Total);
            Count := U64'Min (Count, Available);
            if Count > 0 then
               if not Aligned (Base, Page_Size) or else Count > U64'Last / Page_Size
               then Result := Corrupt; return; end if;
               Physical.Add_Region (Pages, Base, Count * Page_Size, Result);
               if Result /= Success then return; end if;
            end if;
         end if;
      end loop;
      Result := (if Pages.Available > 0 then Success else Out_Of_Memory);
   end Import_Map;
end AxiomOS.Memory.Bootstrap;
