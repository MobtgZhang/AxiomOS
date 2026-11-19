with AxiomOS.Types; use AxiomOS.Types;
with AxiomOS.VFS;
package AxiomOS.IO with Preelaborate is
   Max_Handles : constant := 32;
   type Rights is record
      Read, Write : Boolean := False;
   end record;
   type Handle is new U64;
   Invalid_Handle : constant Handle := 0;
   type Handle_Entry is record
      Node : VFS.Node_Id := 0;
      Offset : U64 := 0;
      Generation : U32 := 1;
      Permissions : Rights;
      Active : Boolean := False;
   end record;
   type Entry_Array is array (Positive range 1 .. Max_Handles) of Handle_Entry;
   type Handle_Table is record
      Entries : Entry_Array;
   end record;
end AxiomOS.IO;
