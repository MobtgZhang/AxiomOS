with AxiomOS.Types; use AxiomOS.Types;
with AxiomOS.Boot.Protocol;
package AxiomOS.HAL.Clock is
   -- Monotonic microseconds since Initialize, shared by timeout callers.
   procedure Initialize (Info : Boot.Protocol.Boot_Info; Result : out Status);
   function Now return U64;
   procedure Delay_US (Duration : U64);
end AxiomOS.HAL.Clock;
