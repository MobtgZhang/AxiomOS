with AxiomOS.Types; use AxiomOS.Types;
with AxiomOS.Boot.Protocol;
with AxiomOS.Memory.Physical;
package AxiomOS.HAL.Secondary is
   function Bootstrap_Id return U64
     with Import, Convention => C, External_Name => "axiom_bootstrap_id";
   function Boot_CPU (Info : Boot.Protocol.Boot_Info) return U64;
   -- Called once on the BSP before any secondary is started.
   procedure Prepare (Info : Boot.Protocol.Boot_Info;
                      Pages : in out Memory.Physical.Allocator; Result : out Status);
   -- Context is a persistent 4 KiB kernel-owned page: stack top at 0,
   -- logical CPU index at 8. Remaining bytes belong exclusively to arch/.
   procedure Start (Hardware_Id, Context : U64; Result : out Status);
end AxiomOS.HAL.Secondary;
