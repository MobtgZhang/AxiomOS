with AxiomOS.Firmware.DeviceTree;
with AxiomOS.Firmware.ACPI.Tables;
with AxiomOS.Raw;
package body AxiomOS.HAL.Counter is
   use type U64, U32;
   function Frequency (Info : Boot.Protocol.Boot_Info) return U64 is
      Rate : constant U64 := Firmware.DeviceTree.Timebase (Info.Device_Tree);
      Table : U64;
      S : Status;
   begin
      if Rate /= 0 then return Rate; end if;
      -- UEFI may publish ACPI without a device tree. RHCT has the architectural
      -- time counter frequency at byte 40 (after its flags field).
      Firmware.ACPI.Tables.Find (Info.ACPI, 16#54434852#, Table, S);
      if S /= Success or else Raw.Load32 (Table + 4) < 56 then return 0; end if;
      return Raw.Load64 (Table + 40);
   end Frequency;
end AxiomOS.HAL.Counter;
