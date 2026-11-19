with AxiomOS.Types; use AxiomOS.Types;
with AxiomOS.Memory.Heap;
with AxiomOS.Memory.Physical;
with Ada.Text_IO;
package body Test_Heap is
   use AxiomOS.Memory;
   use type U64;
   procedure Run is
      H : Heap.Allocator;
      P : Physical.Allocator;
      A : array (0 .. 127) of U64;
      B : U64;
      S : Status;
   begin
      Physical.Reset (P); Physical.Add_Region (P, 16#10000#, 8 * Page_Size, S);
      Heap.Initialize (H);
      for I in A'Range loop
         Heap.Allocate (H, P, 17, 32, A (I), S);
         pragma Assert (S = Success and A (I) mod 32 = 0);
         for J in A'First .. I - 1 loop pragma Assert (A (J) /= A (I)); end loop;
      end loop;
      pragma Assert (P.Available = 7);
      Heap.Free (H, P, A (7) + 1, S); pragma Assert (S = Invalid_Argument);
      Heap.Free (H, P, A (7), S); pragma Assert (S = Success);
      Heap.Free (H, P, A (7), S); pragma Assert (S = Invalid_Argument);
      Heap.Allocate (H, P, 24, 16, B, S); pragma Assert (S = Success and B = A (7));
      for I in A'Range loop Heap.Free (H, P, A (I), S); pragma Assert (S = Success); end loop;
      pragma Assert (P.Available = 8);
      Heap.Allocate (H, P, 5 * Page_Size - 1, Page_Size, B, S); pragma Assert (S = Success and P.Available = 3);
      Heap.Free (H, P, B + Page_Size, S); pragma Assert (S = Invalid_Argument);
      Heap.Free (H, P, B, S); pragma Assert (S = Success and P.Available = 8);
      Heap.Allocate (H, P, 9 * Page_Size, Page_Size, B, S); pragma Assert (S = Out_Of_Memory);
      Heap.Allocate (H, P, 1, 3, B, S); pragma Assert (S = Invalid_Argument);
      Ada.Text_IO.Put_Line ("PASS slab reuse, alignment, double free, reclaim, large allocation, OOM");
   end Run;
end Test_Heap;
