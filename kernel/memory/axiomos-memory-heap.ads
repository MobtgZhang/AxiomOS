with AxiomOS.Types; use AxiomOS.Types;
with AxiomOS.Memory.Physical;
package AxiomOS.Memory.Heap with Preelaborate is
   -- Explicit allocations; no Ada default storage pool or hidden runtime heap.
   -- The caller serializes access. An interrupt handler must not use this heap.
   Max_Slabs : constant := 128;
   type Bitmap is array (0 .. 1) of U64;
   type Slab is record
      Base : U64 := 0;
      Slot_Size : Natural := 0;
      Pages, Used : Natural := 0;
      Allocated : Bitmap := (others => 0);
   end record;
   type Slabs is array (1 .. Max_Slabs) of Slab;
   type Allocator is limited record
      Pools : Slabs;
   end record;
   procedure Initialize (State : in out Allocator);
   procedure Allocate (State : in out Allocator; Pages : in out Physical.Allocator;
                       Length, Alignment : U64; Address : out U64; Result : out Status);
   procedure Free (State : in out Allocator; Pages : in out Physical.Allocator;
                   Address : U64; Result : out Status);
end AxiomOS.Memory.Heap;
