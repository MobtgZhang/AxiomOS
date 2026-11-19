with Ada.Unchecked_Conversion;
with AxiomOS.Firmware.UEFI;
with AxiomOS.Architecture;
with AxiomOS.Raw;
package body AxiomOS.Boot.Handoff is
   use type U16, U32, U64;
   package EFI renames Firmware.UEFI;
   procedure Discover_Tables (Info : in out Protocol.Boot_Info) is
      Count : constant U64 := Raw.Load64 (EFI.System_Table + 104);
      Tables : constant U64 := Raw.Load64 (EFI.System_Table + 112);
      P, Lo, Hi, GOP, Mode : U64;
      S : U64;
      RISCV_GUID : aliased constant EFI.GUID :=
        (16#CCD15FEC#, 16#6F73#, 16#4EEC#, 16#BF40B9E4693E9583#);
      Boot_Protocol : U64;
      type Get_Hart is access function (This : U64; Id : out U64) return U64 with Convention => C;
      function Convert is new Ada.Unchecked_Conversion (U64, Get_Hart);
   begin
      if Count > 0 and then Count <= 1024 then
         for I in 0 .. Count - 1 loop
            P := Tables + I * 24;
            Lo := Raw.Load64 (P); Hi := Raw.Load64 (P + 8);
            if Lo = 16#11D3E4F18868E871# and then Hi = 16#81883CC7800022BC# then
               Info.ACPI := Raw.Load64 (P + 16);
            elsif Lo = 16#41A5F19CB1B621D5# and then Hi = 16#E0AA692C15D90B83# then
               Info.Device_Tree := Raw.Load64 (P + 16);
            end if;
         end loop;
      end if;
      if Architecture.ELF_Machine = 243 then
         S := EFI.Locate_Protocol (RISCV_GUID'Access, Boot_Protocol);
         if S = 0 then
            S := Convert (Raw.Load64 (Boot_Protocol + 8)) (Boot_Protocol, Info.Bootstrap_CPU);
            if S /= 0 then Info.Bootstrap_CPU := U64'Last; end if;
         end if;
      end if;
      S := EFI.Locate_Protocol (EFI.GOP_GUID'Access, GOP);
      if S = 0 then
         Mode := Raw.Load64 (GOP + 24);
         Info.Framebuffer_Base := Raw.Load64 (Mode + 24);
         Info.Framebuffer_Size := Raw.Load64 (Mode + 32);
      end if;
   end Discover_Tables;
   procedure Leave_Firmware (Info : in out Protocol.Boot_Info; Result : out Status) is
      Capacity, Size, Buffer, Map_Key, Desc_Size : U64 := 0;
      Version : U32 := 0;
      S, Ignored : U64;
   begin
      Result := IO_Error;
      S := EFI.Memory_Map (Size, 0, Map_Key, Desc_Size, Version);
      if S /= EFI.Buffer_Too_Small or else Desc_Size < 40 or else Size > 1024 * 1024
      then return; end if;
      Capacity := Size + Desc_Size * 32;
      S := EFI.Allocate_Pool (Capacity, Buffer);
      if S /= 0 then Result := Out_Of_Memory; return; end if;
      -- No output or allocation between a successful GetMemoryMap and exit.
      -- After the first exit attempt only memory-map/exit calls are made.
      for Attempt in 1 .. 4 loop
         Size := Capacity;
         S := EFI.Memory_Map (Size, Buffer, Map_Key, Desc_Size, Version);
         if S /= 0 then return; end if;
         Info.Memory_Map := Buffer;
         Info.Memory_Map_Size := Size;
         Info.Descriptor_Size := Desc_Size;
         Info.Descriptor_Version := Version;
         S := EFI.Exit_Boot_Services (Map_Key);
         if S = 0 then Result := Success; return; end if;
         if S /= EFI.Invalid_Parameter then return; end if;
      end loop;
   end Leave_Firmware;
end AxiomOS.Boot.Handoff;
