with AxiomOS.Types; use AxiomOS.Types;
package AxiomOS.SMP.Topology with Preelaborate is
   procedure Register_CPU (State : in out Manager; Hardware_Id : U64;
                           Bootstrap : Boolean; CPU : out CPU_Index;
                           Result : out Status);
end AxiomOS.SMP.Topology;
