with AxiomOS.Types; use AxiomOS.Types;
with AxiomOS.Boot.Protocol;
package AxiomOS.HAL.Counter is
   function Frequency (Info : Boot.Protocol.Boot_Info) return U64;
end AxiomOS.HAL.Counter;
