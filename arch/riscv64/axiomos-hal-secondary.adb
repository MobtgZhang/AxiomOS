package body AxiomOS.HAL.Secondary is
   use type U64;
   function CPU_On (Hardware_Id, Context : U64) return U64
     with Import, Convention => C, External_Name => "axiom_cpu_on";
   function Boot_CPU (Info : Boot.Protocol.Boot_Info) return U64 is (Info.Bootstrap_CPU);
   procedure Prepare (Info : Boot.Protocol.Boot_Info;
                      Pages : in out Memory.Physical.Allocator; Result : out Status) is
      pragma Unreferenced (Info, Pages);
   begin Result := Success; end Prepare;
   procedure Start (Hardware_Id, Context : U64; Result : out Status) is
   begin
      if CPU_On (Hardware_Id, Context) = 0 then Result := Success;
      else Result := IO_Error; end if;
   end Start;
end AxiomOS.HAL.Secondary;
