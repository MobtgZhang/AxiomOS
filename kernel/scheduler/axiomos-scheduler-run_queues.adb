package body AxiomOS.Scheduler.Run_Queues is
   use type U64;
   procedure Enqueue (State : in out Manager; CPU : CPU_Index; Thread : U32;
                      Result : out Status) is
      C : CPU_Record renames State.CPUs (CPU);
   begin
      Result := Invalid_Argument;
      if C.State /= Online then return; end if;
      if C.Count = C.Queue'Length then Result := No_Space; return; end if;
      C.Queue (C.Tail + 1) := Thread;
      C.Tail := (C.Tail + 1) mod C.Queue'Length;
      C.Count := C.Count + 1;
      Result := Success;
   end Enqueue;

   procedure Dequeue (State : in out Manager; CPU : CPU_Index;
                      Thread : out U32; Result : out Status) is
      C : CPU_Record renames State.CPUs (CPU);
   begin
      Thread := 0;
      Result := Invalid_Argument;
      if C.State /= Online then return; end if;
      if C.Count = 0 then Result := Would_Block; return; end if;
      Thread := C.Queue (C.Head + 1);
      C.Head := (C.Head + 1) mod C.Queue'Length;
      C.Count := C.Count - 1;
      Result := Success;
   end Dequeue;
end AxiomOS.Scheduler.Run_Queues;
