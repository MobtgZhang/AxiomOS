with AxiomOS.HAL.CPU;
package body AxiomOS.IO.Console is
   procedure Write (Buffer : Bytes; Count : out Natural; Result : out Status) is
   begin
      for C of Buffer loop HAL.CPU.Serial_Put (U32 (C)); end loop;
      Count := Buffer'Length;
      Result := Success;
   end Write;
end AxiomOS.IO.Console;
