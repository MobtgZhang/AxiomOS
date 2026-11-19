with AxiomOS.Types; use AxiomOS.Types;
package AxiomOS.Syscall with Preelaborate is
   ABI_Version : constant U32 := 1;
   type Operation is (Exit_Process, Read, Write, Open, Close, Spawn, Wait,
                      Map, Unmap, IPC_Send, IPC_Receive, Clock_Get, Thread_Yield);
   for Operation use (Exit_Process => 0, Read => 1, Write => 2, Open => 3,
                      Close => 4, Spawn => 5, Wait => 6, Map => 7, Unmap => 8,
                      IPC_Send => 9, IPC_Receive => 10, Clock_Get => 11,
                      Thread_Yield => 12);
   type Arguments is array (Natural range 0 .. 4) of U64;
   type Return_Value is record
      Value : U64 := 0;
      Error : Status := Success;
   end record;
end AxiomOS.Syscall;
