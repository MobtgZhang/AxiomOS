with AxiomOS.Boot.Protocol;
with AxiomOS.Memory.Physical;
package AxiomOS.SMP.Bringup is
   procedure Initialize (Info : Boot.Protocol.Boot_Info;
                         Pages : in out Memory.Physical.Allocator;
                         CPUs : in out Manager; Result : out Status);
end AxiomOS.SMP.Bringup;
