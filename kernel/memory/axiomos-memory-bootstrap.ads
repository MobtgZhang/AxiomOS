with AxiomOS.Boot.Protocol;
with AxiomOS.Memory.Physical;
with AxiomOS.Types; use AxiomOS.Types;
package AxiomOS.Memory.Bootstrap is
   procedure Import_Map (Info : Boot.Protocol.Boot_Info;
                         Pages : in out Physical.Allocator; Result : out Status);
end AxiomOS.Memory.Bootstrap;
