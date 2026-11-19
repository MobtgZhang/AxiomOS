with AxiomOS.Types; use AxiomOS.Types;
package AxiomOS.Boot.ELF with Preelaborate is
   Max_Segments : constant := 16;
   type Segment is record
      Offset, Virtual_Base, File_Size, Memory_Size, Alignment : U64 := 0;
      Flags : U32 := 0;
   end record;
   type Segment_Array is array (Positive range 1 .. Max_Segments) of Segment;
   type Layout is record
      Entry_Point, Span, Dynamic_Offset, Dynamic_Size : U64 := 0;
      Count : Natural := 0;
      Segments : Segment_Array;
   end record;
   function LE16 (Image : Bytes; Offset : Natural) return U16;
   function LE32 (Image : Bytes; Offset : Natural) return U32;
   function LE64 (Image : Bytes; Offset : Natural) return U64;
   procedure Validate (Image : Bytes; Machine : U16; Plan : out Layout;
                       Result : out Status; Expected_Type : U16 := 3);
end AxiomOS.Boot.ELF;
