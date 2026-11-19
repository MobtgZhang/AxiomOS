with AxiomOS.Types; use AxiomOS.Types;
package AxiomOS.SMP with Preelaborate is
   Max_CPUs : constant := 64;
   subtype CPU_Index is Natural range 0 .. Max_CPUs - 1;
   type CPU_State is (Absent, Offline, Starting, Online, Failed);
   type Run_Queue is array (Positive range 1 .. 32) of U32;
   type CPU_Record is record
      Hardware_Id : U64 := 0;
      State : CPU_State := Absent;
      Deadline : U64 := 0;
      Queue : Run_Queue := (others => 0);
      Head, Tail, Count : Natural := 0;
   end record;
   type CPU_Array is array (CPU_Index) of CPU_Record;
   type Manager is record
      CPUs : CPU_Array;
      Bootstrap : CPU_Index := 0;
      Count : Natural := 0;
   end record;
end AxiomOS.SMP;
