with AxiomOS.Memory.Physical;
with AxiomOS.VFS;
with AxiomOS.IO;
with AxiomOS.SMP;
with AxiomOS.Drivers;
package AxiomOS.Kernel.State is
   Pages : Memory.Physical.Allocator;
   Files : VFS.File_System;
   Handles : IO.Handle_Table;
   CPUs : SMP.Manager;
   Devices : Drivers.Manager;
   procedure Initialize;
end AxiomOS.Kernel.State;
