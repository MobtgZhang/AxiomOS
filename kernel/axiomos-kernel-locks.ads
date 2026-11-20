with AxiomOS.HAL.CPU;
with AxiomOS.Raw;
with AxiomOS.Sync;
--  Kernel instantiation of AxiomOS.Sync bound to the architecture atomics.
--  A child of the generic package is illegal, so the instantiation lives in
--  its own unit under AxiomOS.Kernel.
package AxiomOS.Kernel.Locks is new AxiomOS.Sync
  (AxiomOS.Raw.Number,
   AxiomOS.HAL.CPU.Compare_Exchange,
   AxiomOS.HAL.CPU.Fetch_Add,
   AxiomOS.HAL.CPU.Pause);
