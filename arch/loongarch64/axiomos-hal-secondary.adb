package body AxiomOS.HAL.Secondary is
   use type U64;
   procedure CPU_On (Hardware_Id, Context : U64)
     with Import, Convention => C, External_Name => "axiom_cpu_on";
   function Boot_CPU (Info : Boot.Protocol.Boot_Info) return U64 is (Bootstrap_Id);
   procedure Prepare (Info : Boot.Protocol.Boot_Info;
                      Pages : in out Memory.Physical.Allocator; Result : out Status) is
      pragma Unreferenced (Info, Pages);
   begin Result := Success; end Prepare;
   procedure Start (Hardware_Id, Context : U64; Result : out Status) is
   begin
      if Hardware_Id > 1023 then Result := Unsupported; return; end if;
      CPU_On (Hardware_Id, Context); Result := Success;
   end Start;
end AxiomOS.HAL.Secondary;
