with AxiomOS.Types; use AxiomOS.Types;
package AxiomOS.SMP.Work is
   type Operation is access procedure (CPU : CPU_Index; Argument : U64; Result : out Status);
   type Ticket is new U64;
   Invalid_Ticket : constant Ticket := 0;
   procedure Initialize;
   procedure Enable (CPU : CPU_Index);
   -- One outstanding job per CPU. A timed-out ticket remains owned by the
   -- caller and can be collected later; its argument must remain alive.
   procedure Submit (CPU : CPU_Index; Action : Operation; Argument : U64;
                     Job : out Ticket; Result : out Status);
   procedure Collect (Job : Ticket; Result : out Status; Completed : out Boolean);
   procedure Wait (Job : Ticket; Timeout_US : U64; Result : out Status);
   procedure Serve (CPU : CPU_Index) with No_Return;
end AxiomOS.SMP.Work;
