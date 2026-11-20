with Ada.Text_IO;
with System;
with System.Storage_Elements;
with AxiomOS.Types; use AxiomOS.Types;
with AxiomOS.Sync;
package body Test_Sync is
   use type U32, U64;

   function Fake_Number (Address : System.Address) return U64 is
     (U64 (System.Storage_Elements.To_Integer (Address)));

   --  Pure-Ada stand-in for the architecture atomics: a large direct-mapped
   --  RAM of 32-bit cells indexed by word address; no concurrency, but
   --  identical return conventions.
   RAM : array (Natural range 0 .. 65535) of U32 := (others => 0);

   function Fake_CAS (Address : U64; Expected, New_Value : U32) return U32 is
      Cell : constant Natural := Natural ((Address / 4) mod 65536);
      Old : constant U32 := RAM (Cell);
   begin
      if Old = Expected then RAM (Cell) := New_Value; end if;
      return Old;
   end Fake_CAS;

   function Fake_Fetch_Add (Address : U64; Value : U32) return U32 is
      Cell : constant Natural := Natural ((Address / 4) mod 65536);
      Old : constant U32 := RAM (Cell);
   begin
      RAM (Cell) := Old + Value;
      return Old;
   end Fake_Fetch_Add;

   procedure Fake_Pause is null;

   package Sync is new AxiomOS.Sync
     (Fake_Number, Fake_CAS, Fake_Fetch_Add, Fake_Pause);

   procedure Run is
      Lock : Sync.Spinlock;
      Guard : Sync.Mutex;
      Sema : Sync.Semaphore;
      S : Status;
   begin
      RAM := (others => 0);

      Sync.Initialize (Lock);
      Sync.Acquire (Lock);
      Sync.Release (Lock);
      --  Tickets wrap modulo 2**32; drive a full generation of hand-outs.
      for I in 0 .. 999 loop
         Sync.Acquire (Lock);
         Sync.Release (Lock);
      end loop;
      Ada.Text_IO.Put_Line ("PASS ticket spinlock acquire/release");

      Sync.Acquire (Guard, 7, S);
      pragma Assert (S = Success);
      pragma Assert (Sync.Try_Acquire (Guard, 8) = Would_Block);
      pragma Assert (Sync.Try_Acquire (Guard, 7) = Invalid_Argument);
      Sync.Release (Guard, 8, S);
      pragma Assert (S = Permission_Denied);
      Sync.Release (Guard, 7, S);
      pragma Assert (S = Success);
      Sync.Release (Guard, 7, S);
      pragma Assert (S = Permission_Denied); -- already free
      S := Sync.Try_Acquire (Guard, 9);
      pragma Assert (S = Success);
      Sync.Release (Guard, 9, S);
      pragma Assert (S = Success);
      Ada.Text_IO.Put_Line ("PASS mutex ownership, recursion rejection, double release");

      Sync.Initialize (Sema, 1, 3);
      Sync.Up (Sema, S);
      pragma Assert (S = Success);
      Sync.Up (Sema, S);
      pragma Assert (S = Success);
      Sync.Up (Sema, S);
      pragma Assert (S = No_Space); -- maximum reached
      pragma Assert (Sync.Try_Down (Sema) = Success);
      pragma Assert (Sync.Try_Down (Sema) = Success);
      pragma Assert (Sync.Try_Down (Sema) = Success);
      pragma Assert (Sync.Try_Down (Sema) = Would_Block);
      Sync.Initialize (Sema, 5, 3);
      pragma Assert (Sync.Try_Down (Sema) = Success);
      pragma Assert (Sync.Try_Down (Sema) = Success);
      pragma Assert (Sync.Try_Down (Sema) = Success);
      pragma Assert (Sync.Try_Down (Sema) = Would_Block); -- clamped to maximum
      Ada.Text_IO.Put_Line ("PASS semaphore bounds, clamp, exhaustion");
   end Run;
end Test_Sync;
