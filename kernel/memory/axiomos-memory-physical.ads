with AxiomOS.Types; use AxiomOS.Types;
package AxiomOS.Memory.Physical with Preelaborate is
   Max_Pages : constant := 131_072;
   Max_Regions : constant := 128;
   type Owner is (Free, Kernel, Page_Table, Process, DMA, Firmware);
   type Page_Metadata is record
      Kind : Owner := Free;
      References : U16 := 0;
   end record;
   type Metadata_Array is array (Natural range 0 .. Max_Pages - 1)
     of Page_Metadata;
   type Region is record
      Base : U64 := 0;
      Pages, Offset : Natural := 0;
   end record;
   type Region_Array is array (Positive range 1 .. Max_Regions) of Region;
   type Allocator is limited record
      Regions : Region_Array;
      Region_Count, Total, Available : Natural := 0;
      Metadata : Metadata_Array;
   end record;
   procedure Reset (State : in out Allocator);
   procedure Add_Region (State : in out Allocator; Base, Length : U64;
                         Result : out Status);
   procedure Allocate (State : in out Allocator; Count : Positive;
                       Alignment : U64; Kind : Owner;
                       Address : out U64; Result : out Status);
   procedure Release (State : in out Allocator; Address : U64;
                      Count : Positive; Result : out Status);
   procedure Retain (State : in out Allocator; Address : U64;
                     Result : out Status);
   function Free_Pages (State : Allocator) return Natural is (State.Available);
end AxiomOS.Memory.Physical;
