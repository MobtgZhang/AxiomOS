with AxiomOS.Storage;
with AxiomOS.Types; use AxiomOS.Types;
package AxiomOS.VFS with Preelaborate is
   Max_Nodes : constant := 64;
   Max_File_Size : constant := 32768;
   Max_Path : constant := 127;
   Max_Mounts : constant := 8;
   subtype Mount_Id is Positive range 1 .. Max_Mounts;
   type Mount_Record is record
      Active : Boolean := False;
      Memory_Backed : Boolean := True;
      Path : String (1 .. Max_Path) := (others => Character'Val (0));
      Path_Length : Natural := 0;
      Disk : Storage.Volume;
   end record;
   type Mount_Array is array (Mount_Id) of Mount_Record;
   subtype Node_Id is Natural range 0 .. Max_Nodes;
   type Node_Kind is (Unused, Directory, Regular, Character_Device);
   type Node is record
      Kind : Node_Kind := Unused;
      Path : String (1 .. Max_Path) := (others => Character'Val (0));
      Path_Length : Natural := 0;
      Read_Only : Boolean := False;
      Length : Natural := 0;
      Backed : Boolean := False;
      Mount : Mount_Id := 1;
      Open_Count : Natural := 0;
      Object : Storage.File_Object;
      Data : Bytes (0 .. Max_File_Size - 1) := (others => 0);
   end record;
   type Node_Array is array (Positive range 1 .. Max_Nodes) of Node;
   type File_System is limited record
      Nodes : Node_Array;
      Root_Volume : Storage.Volume;
      Mounts : Mount_Array;
   end record;
end AxiomOS.VFS;
