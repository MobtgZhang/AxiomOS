with AxiomOS.Types; use AxiomOS.Types;
with AxiomOS.Boot.Protocol;
package AxiomOS.Boot.Handoff is
   procedure Discover_Tables (Info : in out Protocol.Boot_Info);
   procedure Leave_Firmware (Info : in out Protocol.Boot_Info; Result : out Status);
end AxiomOS.Boot.Handoff;
