package body AxiomOS.Drivers.Lifecycle is
   use type U16, U64;
   procedure Set_Running (State : in out Manager; Id : Natural;
                          Result : out Status) is
   begin
      Result := Invalid_Argument;
      if Id not in State.Devices'Range then return; end if;
      if State.Devices (Id).State /= Bound then return; end if;
      if State.Devices (Id).Driver not in State.Drivers'Range then Result := Corrupt; return; end if;
      if State.Drivers (State.Devices (Id).Driver).Start /= null then
         State.Drivers (State.Devices (Id).Driver).Start (State.Devices (Id), Result);
         if Result /= Success then State.Devices (Id).State := Failed; return; end if;
      end if;
      State.Devices (Id).State := Running;
      Result := Success;
   end Set_Running;
   procedure Stop (State : in out Manager; Id : Natural; Result : out Status) is
      Driver : Natural;
   begin
      Result := Invalid_Argument;
      if Id not in State.Devices'Range then return; end if;
      if State.Devices (Id).State not in Running | Failed then return; end if;
      Driver := State.Devices (Id).Driver;
      if Driver not in State.Drivers'Range then Result := Corrupt; return; end if;
      Result := Unsupported;
      if State.Drivers (Driver).Stop = null then return; end if;
      State.Drivers (Driver).Stop (State.Devices (Id), Result);
      if Result = Success then State.Devices (Id).State := Bound; end if;
   end Stop;
   procedure Remove (State : in out Manager; Id : Natural; Result : out Status) is
   begin
      Result := Invalid_Argument;
      if Id not in State.Devices'Range or else State.Devices (Id).State = Unused
      then return; end if;
      if State.Devices (Id).State in Running | Failed then Result := Busy; return; end if;
      State.Devices (Id) := (others => <>);
      Result := Success;
   end Remove;
end AxiomOS.Drivers.Lifecycle;
