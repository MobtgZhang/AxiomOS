with AxiomOS.HAL.CPU;
package body AxiomOS.HAL.Console is
   use type U64;
   procedure Put (Text : String) is
   begin
      for C of Text loop CPU.Serial_Put (Character'Pos (C)); end loop;
   end Put;
   procedure Line (Text : String) is
   begin
      Put (Text);
      Put (ASCII.CR & ASCII.LF);
   end Line;
   procedure Hex (Value : U64) is
      Hex_Digits : constant String := "0123456789ABCDEF";
      Buffer : String (1 .. 16);
      Remaining : U64 := Value;
   begin
      Put ("0x");
      for I in reverse Buffer'Range loop
         Buffer (I) := Hex_Digits (Natural (Remaining mod 16) + 1);
         Remaining := Remaining / 16;
      end loop;
      Put (Buffer);
   end Hex;
   procedure Panic (Text : String) is
   begin
      CPU.Disable_Interrupts;
      Line ("AxiomOS PANIC: " & Text);
      CPU.Halt;
   end Panic;
end AxiomOS.HAL.Console;
