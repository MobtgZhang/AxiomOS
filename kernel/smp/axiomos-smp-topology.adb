package body AxiomOS.SMP.Topology is
   use type U64;
   procedure Register_CPU (State : in out Manager; Hardware_Id : U64;
                           Bootstrap : Boolean; CPU : out CPU_Index;
                           Result : out Status) is
   begin
      CPU := 0;
      Result := Already_Exists;
      for I in 0 .. State.Count - 1 loop
         if State.CPUs (I).Hardware_Id = Hardware_Id or else
           (Bootstrap and then State.CPUs (I).State = Online)
         then return; end if;
      end loop;
      if State.Count = Max_CPUs then Result := No_Space; return; end if;
      CPU := State.Count;
      State.Count := State.Count + 1;
      State.CPUs (CPU).Hardware_Id := Hardware_Id;
      State.CPUs (CPU).State := (if Bootstrap then Online else Offline);
      if Bootstrap then State.Bootstrap := CPU; end if;
      Result := Success;
   end Register_CPU;

end AxiomOS.SMP.Topology;
