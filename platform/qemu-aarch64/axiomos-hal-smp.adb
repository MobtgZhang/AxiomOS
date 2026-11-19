with AxiomOS.SMP.Bringup;
package body AxiomOS.HAL.SMP is
   procedure Initialize (Info : Boot.Protocol.Boot_Info;
                         Pages : in out Memory.Physical.Allocator;
                         CPUs : in out AxiomOS.SMP.Manager; Result : out Status) is
   begin AxiomOS.SMP.Bringup.Initialize (Info, Pages, CPUs, Result); end Initialize;
end AxiomOS.HAL.SMP;
