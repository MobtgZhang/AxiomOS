with AxiomOS.Types; use AxiomOS.Types;
with AxiomOS.Boot.Protocol;
with AxiomOS.Memory.Physical;
with AxiomOS.SMP;
package AxiomOS.HAL.SMP is
   procedure Initialize (Info : Boot.Protocol.Boot_Info;
                         Pages : in out Memory.Physical.Allocator;
                         CPUs : in out AxiomOS.SMP.Manager; Result : out Status);
end AxiomOS.HAL.SMP;
