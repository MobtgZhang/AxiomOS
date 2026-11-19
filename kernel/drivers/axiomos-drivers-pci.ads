with AxiomOS.Boot.Protocol;
package AxiomOS.Drivers.PCI is
   procedure Find_Virtio_Block (Info : Boot.Protocol.Boot_Info;
                                Config, Common, Notify, Device_Config : out U64;
                                Multiplier : out U32; Result : out Status);
end AxiomOS.Drivers.PCI;
