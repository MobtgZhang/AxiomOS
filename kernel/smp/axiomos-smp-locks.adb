with AxiomOS.Raw;
with AxiomOS.HAL.CPU;
package body AxiomOS.SMP.Locks is
   procedure Initialize (Lock : out Spinlock) is
   begin Lock.Word := 0; end Initialize;
   use type U32;
   procedure Acquire (Lock : in out Spinlock) is
   begin
      while HAL.CPU.Exchange (Raw.Number (Lock.Word'Address), 1) /= 0 loop
         HAL.CPU.Pause;
      end loop;
   end Acquire;
   procedure Release (Lock : in out Spinlock) is
   begin HAL.CPU.Release (Raw.Number (Lock.Word'Address)); end Release;
end AxiomOS.SMP.Locks;
