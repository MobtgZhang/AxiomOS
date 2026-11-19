package body AxiomOS.HAL.Context is
   procedure Setup (Kernel_Stack : U64)
     with Import, Convention => C, External_Name => "axiom_context_setup";
   procedure Initialize (Kernel_Stack : U64; Result : out Status) is
   begin Setup (Kernel_Stack); Result := Success; end Initialize;
end AxiomOS.HAL.Context;
