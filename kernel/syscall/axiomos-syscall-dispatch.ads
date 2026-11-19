with AxiomOS.Process;
with AxiomOS.VFS;
generic
   with procedure Copy_In (Caller : AxiomOS.Process.Process_Record;
                           Address : U64; Buffer : out Bytes; Result : out Status);
   with procedure Copy_Out (Caller : AxiomOS.Process.Process_Record;
                            Address : U64; Buffer : Bytes; Result : out Status);
package AxiomOS.Syscall.Dispatch is
   procedure Invoke (Processes : in out AxiomOS.Process.Manager;
                     Caller : AxiomOS.Process.PID;
                     Files : in out AxiomOS.VFS.File_System;
                     Number : U64; Args : Arguments; Reply : out Return_Value);
end AxiomOS.Syscall.Dispatch;
