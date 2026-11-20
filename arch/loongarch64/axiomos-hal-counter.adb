package body AxiomOS.HAL.Counter is
   function Hardware_Frequency return U64
     with Import, Convention => C, External_Name => "axiom_counter_frequency";
   function Frequency (Info : Boot.Protocol.Boot_Info) return U64 is
      pragma Unreferenced (Info);
   begin return Hardware_Frequency; end Frequency;
end AxiomOS.HAL.Counter;
