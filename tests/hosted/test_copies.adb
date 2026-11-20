with Ada.Text_IO;
with System.Storage_Elements;
with AxiomOS.Types; use AxiomOS.Types;
with AxiomOS.Memory.Virtual;
with AxiomOS.Security.Copies;
package body Test_Copies is
   use AxiomOS;
   use type U64;
   function Number (A : System.Address) return U64 is
     (U64 (System.Storage_Elements.To_Integer (A)));
   procedure Move (Target, Source, Length : U64) is
      D : Bytes (0 .. Natural (Length) - 1) with Import,
        Address => System.Storage_Elements.To_Address (System.Storage_Elements.Integer_Address (Target));
      S : Bytes (0 .. Natural (Length) - 1) with Import,
        Address => System.Storage_Elements.To_Address (System.Storage_Elements.Integer_Address (Source));
   begin D := S; end Move;
   package Copies is new Security.Copies (Move, Number);
   procedure Run is
      First, Second : aliased Bytes (0 .. 4095) with Alignment => 4096;
      Data : Bytes (0 .. 7);
      Space : Memory.Virtual.Address_Space;
      S : Status;
   begin
      First := (others => 65); Second := (others => 66);
      Memory.Virtual.Map (Space, 4096, Number (First'Address), 4096, (True, True, False, True, False), S);
      pragma Assert (S = Success);
      Memory.Virtual.Map (Space, 8192, Number (Second'Address), 4096, (True, True, False, True, False), S);
      pragma Assert (S = Success);
      Copies.Read (Space, 8188, Data, S);
      pragma Assert (S = Success and Data = (65, 65, 65, 65, 66, 66, 66, 66));
      Copies.Write (Space, 8188, (1, 2, 3, 4, 5, 6, 7, 8), S);
      pragma Assert (S = Success and First (4092 .. 4095) = (1, 2, 3, 4) and Second (0 .. 3) = (5, 6, 7, 8));
      Space.Entries (2).Access_Rights.Writable := False;
      Copies.Write (Space, 8188, (0 .. 7 => 99), S);
      pragma Assert (S = Permission_Denied and First (4092 .. 4095) = (1, 2, 3, 4));
      Memory.Virtual.Unmap (Space, 8192, 4096, S);
      Copies.Read (Space, 8188, Data, S);
      pragma Assert (S = Permission_Denied and Data = (0, 0, 0, 0, 0, 0, 0, 0));
      Ada.Text_IO.Put_Line ("PASS cross-mapping user copies and validation before partial writes");
   end Run;
end Test_Copies;
