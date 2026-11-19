with AxiomOS.Types; use AxiomOS.Types;
with AxiomOS.Memory.Virtual;
with AxiomOS.IO;
package AxiomOS.Process with Preelaborate is
   Max_Processes : constant := 16;
   type PID is new U64;
   Kernel_PID : constant PID := 0;
   type Lifecycle is (Unused, Created, Ready, Running, Blocked, Zombie);
   type Credentials is record
      User_Id, Group_Id : U32 := 1000;
   end record;
   type Process_Record is record
      State : Lifecycle := Unused;
      Generation : U32 := 1;
      Parent : PID := Kernel_PID;
      Identity : Credentials;
      Space : Memory.Virtual.Address_Space;
      Hardware_Root : U64 := 0;
      Handles : IO.Handle_Table;
      Entry_Point, Stack_Top : U64 := 0;
      Exit_Code : U32 := 0;
   end record;
   type Process_Array is array (Positive range 1 .. Max_Processes) of Process_Record;
   type Manager is limited record
      Entries : Process_Array;
   end record;
end AxiomOS.Process;
