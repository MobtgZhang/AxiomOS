--  Synchronisation structures shared by all architectures.
--
--  The package is generic over the HAL atomics so hosted tests can
--  instantiate it with pure Ada replacements while the kernel binds the
--  architecture primitives. Every primitive operates on exactly one aligned
--  32-bit word and provides acquire/release ordering.
with System;
with AxiomOS.Types; use AxiomOS.Types;
generic
   --  Converts a word address to its integer form so the package stays
   --  Preelaborate without depending on the runtime helper package.
   with function Number (Address : System.Address) return U64;
   --  Returns the previous word unconditionally; callers compare it with
   --  Expected themselves.
   with function Compare_Exchange (Address : U64; Expected, New_Value : U32) return U32;
   --  Returns the previous word and stores the sum, wrapping modulo 2**32.
   with function Fetch_Add (Address : U64; Value : U32) return U32;
   --  CPU relaxation hint used inside every busy loop.
   with procedure Pause;
package AxiomOS.Sync with Preelaborate is
   --  Ticket spinlock: Acquire hands out monotonically increasing tickets and
   --  busy-waits until the grant counter reaches the caller's ticket, so
   --  waiters enter in FIFO order instead of racing on one word.
   type Spinlock is limited private;
   procedure Initialize (Lock : out Spinlock);
   procedure Acquire (Lock : in out Spinlock);
   procedure Release (Lock : in out Spinlock);

   --  Mutex: ownership-tracked lock. Holders are identified by a caller
   --  chosen owner token (for example a CPU index); only the owner may
   --  release. There is no blocking scheduler yet, so Acquire busy-waits;
   --  the Acquire/Try_Acquire/Release split keeps the future wait path
   --  replaceable without touching callers.
   type Mutex is limited private;
   No_Owner : constant U64 := 0;
   --  Recursive acquisition returns Invalid_Argument instead of deadlocking.
   procedure Acquire (Lock : in out Mutex; Owner : U64; Result : out Status);
   function Try_Acquire (Lock : in out Mutex; Owner : U64) return Status;
   procedure Release (Lock : in out Mutex; Owner : U64; Result : out Status);

   --  Counting semaphore with a fixed maximum. Down/Try_Down consume one
   --  unit, Up returns one unit; the count never exceeds the maximum.
   type Semaphore is limited private;
   procedure Initialize (Sema : out Semaphore; Initial, Maximum : U32);
   procedure Up (Sema : in out Semaphore; Result : out Status);
   function Try_Down (Sema : in out Semaphore) return Status;
   procedure Down (Sema : in out Semaphore);
private
   type Spinlock is limited record
      Ticket : aliased U32 := 0 with Atomic;
      Grant  : aliased U32 := 0 with Atomic;
   end record;
   type Mutex is limited record
      State : aliased U32 := 0 with Atomic; -- 0 free, 1 held
      Owner : U64 := No_Owner;              -- written only by the holder
   end record;
   type Semaphore is limited record
      Count   : aliased U32 := 0 with Atomic;
      Maximum : U32 := 0;
   end record;
end AxiomOS.Sync;
