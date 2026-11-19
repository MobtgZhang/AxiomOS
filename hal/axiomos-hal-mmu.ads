with AxiomOS.Types; use AxiomOS.Types;
with AxiomOS.Memory.Physical;
with AxiomOS.Memory.Virtual;
with AxiomOS.Boot.Protocol;
package AxiomOS.HAL.MMU is
   -- On failure Create releases partial tables and returns Root = 0.
   procedure Create (Pages : in out Memory.Physical.Allocator;
                     Info : Boot.Protocol.Boot_Info; Root : out U64;
                     Result : out Status);
   procedure Map_Page (Pages : in out Memory.Physical.Allocator;
                       Root, Virtual_Base, Physical_Base : U64;
                       Rights : Memory.Virtual.Permissions; Result : out Status);
   procedure Activate (Root : U64);
   procedure Destroy (Pages : in out Memory.Physical.Allocator; Root : U64);
end AxiomOS.HAL.MMU;
