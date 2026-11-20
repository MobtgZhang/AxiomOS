with AxiomOS.HAL.CPU;
with AxiomOS.HAL.Counter;
package body AxiomOS.HAL.Clock is
   use type U64;
   Rate, Epoch : U64;
   procedure Initialize (Info : Boot.Protocol.Boot_Info; Result : out Status) is
   begin
      Rate := Counter.Frequency (Info);
      Epoch := CPU.Ticks;
      Result := (if Rate > 0 and then Rate <= 10 ** 12 then Success else Unsupported);
   end Initialize;
   function Now return U64 is
      Elapsed : constant U64 := CPU.Ticks - Epoch;
   begin
      if Rate = 0 then return 0; end if;
      return (Elapsed / Rate) * 1_000_000 + (Elapsed mod Rate) * 1_000_000 / Rate;
   end Now;
   procedure Delay_US (Duration : U64) is
      First : constant U64 := Now;
   begin
      while Now - First < Duration loop CPU.Pause; end loop;
   end Delay_US;
end AxiomOS.HAL.Clock;
