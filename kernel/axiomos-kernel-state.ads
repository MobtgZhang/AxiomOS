with AxiomOS.Memory.Physical;
with AxiomOS.VFS;
with AxiomOS.IO;
with AxiomOS.SMP;
with AxiomOS.Drivers;
with AxiomOS.Jobs;
--  Preelaborate keeps this state free of package elaboration code; the
--  freestanding entry has no binder or adainit.
package AxiomOS.Kernel.State with Preelaborate is
   Pages : Memory.Physical.Allocator;
   Files : VFS.File_System;
   Handles : IO.Handle_Table;
   CPUs : SMP.Manager;
   Devices : Drivers.Manager;
   Job_Table : Jobs.Manager;
   procedure Initialize;
end AxiomOS.Kernel.State;
