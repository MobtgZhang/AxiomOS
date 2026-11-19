package body AxiomOS.Drivers.Lifecycle is
   use type U16, U64;
   procedure Set_Running (State : in out Manager; Id : Natural;
                          Result : out Status) is
   begin
      Result := Invalid_Argument;
      if Id not in State.Devices'Range then return; end if;
      if State.Devices (Id).State /= Bound then return; end if;
      State.Devices (Id).State := Running;
      Result := Success;
   end Set_Running;
   procedure Remove (State : in out Manager; Id : Natural; Result : out Status) is
   begin
      Result := Invalid_Argument;
      if Id not in State.Devices'Range or else State.Devices (Id).State = Unused
      then return; end if;
      State.Devices (Id) := (others => <>);
      Result := Success;
   end Remove;
end AxiomOS.Drivers.Lifecycle;
