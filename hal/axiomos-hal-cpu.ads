with AxiomOS.Types; use AxiomOS.Types;
package AxiomOS.HAL.CPU with Preelaborate is
   procedure Serial_Put (Value : U32)
     with Import, Convention => C, External_Name => "axiom_serial_put";
   procedure Halt with Import, Convention => C,
     External_Name => "axiom_halt", No_Return;
   procedure Disable_Interrupts with Import, Convention => C,
     External_Name => "axiom_disable_interrupts";
   procedure Pause with Import, Convention => C,
     External_Name => "axiom_pause";
   procedure Handoff (Entry_Point, Info, Stack_Top : U64)
     with Import, Convention => C, External_Name => "axiom_handoff", No_Return;
   procedure Sync_Code (Base, Length : U64)
     with Import, Convention => C, External_Name => "axiom_sync_code";
   function Exchange (Address : U64; Value : U32) return U32
     with Import, Convention => C, External_Name => "axiom_exchange";
   procedure Release (Address : U64)
     with Import, Convention => C, External_Name => "axiom_release";
   procedure Fence with Import, Convention => C, External_Name => "axiom_fence";
   function Ticks return U64
     with Import, Convention => C, External_Name => "axiom_ticks";
end AxiomOS.HAL.CPU;
