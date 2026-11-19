package body AxiomOS.SMP.Startup is
   use type U64;
   procedure Begin_Start (State : in out Manager; CPU : CPU_Index;
                          Now, Timeout : U64; Result : out Status) is
   begin
      Result := Invalid_Argument;
      if Timeout = 0 or else Now > U64'Last - Timeout then return; end if;
      if State.CPUs (CPU).State /= Offline then Result := Busy; return; end if;
      State.CPUs (CPU).State := Starting;
      State.CPUs (CPU).Deadline := Now + Timeout;
      Result := Success;
   end Begin_Start;

   procedure Acknowledge (State : in out Manager; CPU : CPU_Index;
                          Result : out Status) is
   begin
      Result := Invalid_Argument;
      if State.CPUs (CPU).State /= Starting then return; end if;
      State.CPUs (CPU).State := Online;
      Result := Success;
   end Acknowledge;

   procedure Expire (State : in out Manager; Now : U64) is
   begin
      for C of State.CPUs loop
         if C.State = Starting and then Now >= C.Deadline then
            C.State := Failed;
         end if;
      end loop;
   end Expire;

end AxiomOS.SMP.Startup;
