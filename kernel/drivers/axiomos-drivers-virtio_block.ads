with AxiomOS.Boot.Protocol;
with AxiomOS.Memory.Physical;
package AxiomOS.Drivers.Virtio_Block is
   procedure Initialize (Info : Boot.Protocol.Boot_Info;
                         Pages : in out Memory.Physical.Allocator; Result : out Status);
   procedure Read (Offset : U64; Buffer : out Bytes; Result : out Status);
   function Capacity return U64;
   function Common_Address return U64;
   function Notify_Address return U64;
end AxiomOS.Drivers.Virtio_Block;
