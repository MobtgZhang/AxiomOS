with AxiomOS.Types; use AxiomOS.Types;
package AxiomOS.SMP.Startup with Preelaborate is
   procedure Begin_Start (State : in out Manager; CPU : CPU_Index;
                          Now, Timeout : U64; Result : out Status);
   procedure Acknowledge (State : in out Manager; CPU : CPU_Index;
                          Result : out Status);
   procedure Expire (State : in out Manager; Now : U64);
end AxiomOS.SMP.Startup;
