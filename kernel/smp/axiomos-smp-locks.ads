with AxiomOS.Types; use AxiomOS.Types;
package AxiomOS.SMP.Locks is
   type Spinlock is limited private;
   procedure Initialize (Lock : out Spinlock);
   procedure Acquire (Lock : in out Spinlock);
   procedure Release (Lock : in out Spinlock);
private
   type Spinlock is limited record
      Word : aliased U32 := 0 with Atomic;
   end record;
end AxiomOS.SMP.Locks;
