with AxiomOS.SMP; use AxiomOS.SMP;
with AxiomOS.Types; use AxiomOS.Types;
package AxiomOS.Scheduler.Run_Queues with Preelaborate is
   procedure Enqueue (State : in out Manager; CPU : CPU_Index; Thread : U32;
                      Result : out Status);
   procedure Dequeue (State : in out Manager; CPU : CPU_Index;
                      Thread : out U32; Result : out Status);
end AxiomOS.Scheduler.Run_Queues;
