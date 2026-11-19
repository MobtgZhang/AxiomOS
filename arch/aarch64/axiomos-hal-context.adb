package body AxiomOS.HAL.Context is
   use type U64;
   function Setup (Kernel_Stack : U64) return U64
     with Import, Convention => C, External_Name => "axiom_context_setup";
   procedure Initialize (Kernel_Stack : U64; Result : out Status) is
   begin
      if Setup (Kernel_Stack) = 1 then Result := Success;
      else Result := Unsupported; end if;
   end Initialize;
end AxiomOS.HAL.Context;
