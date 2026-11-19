package body AxiomOS.IO.Console is
   procedure Write (Buffer : Bytes; Count : out Natural; Result : out Status) is
   begin
      Count := Buffer'Length;
      Result := Success;
   end Write;
end AxiomOS.IO.Console;
