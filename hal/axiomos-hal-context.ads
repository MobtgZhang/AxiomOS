with AxiomOS.Types; use AxiomOS.Types;
package AxiomOS.HAL.Context is
   procedure Initialize (Kernel_Stack : U64; Result : out Status);
   function Enter_User (Entry_Point, Stack_Top : U64) return U64
     with Import, Convention => C, External_Name => "axiom_enter_user";
   procedure Leave_User (Exit_Code : U64)
     with Import, Convention => C, External_Name => "axiom_leave_user", No_Return;
end AxiomOS.HAL.Context;
