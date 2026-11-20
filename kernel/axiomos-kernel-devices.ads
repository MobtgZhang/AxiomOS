with AxiomOS.Boot.Protocol;
with AxiomOS.Types; use AxiomOS.Types;
package AxiomOS.Kernel.Devices is
   procedure Initialize (Info : Boot.Protocol.Boot_Info; Result : out Status);
   procedure Check_Concurrent (Result : out Status);
end AxiomOS.Kernel.Devices;
