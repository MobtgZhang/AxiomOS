package body AxiomOS.Drivers.Registry is
   use type U16, U64;
   procedure Register_Driver (State : in out Manager; Class : Device_Class;
                              Vendor, Product : U16; Id : out Natural;
                              Result : out Status;
                              Start : Lifecycle_Action := null;
                              Stop : Lifecycle_Action := null) is
   begin
      Id := 0;
      for D of State.Drivers loop
         if D.Active and then D.Class = Class and then D.Vendor = Vendor and then
           D.Product = Product
         then Result := Already_Exists; return; end if;
      end loop;
      for I in State.Drivers'Range loop
         if not State.Drivers (I).Active then
            State.Drivers (I) := (True, Class, Vendor, Product, Start, Stop);
            Id := I;
            Result := Success;
            return;
         end if;
      end loop;
      Result := No_Space;
   end Register_Driver;
   procedure Discover (State : in out Manager; Description : Device;
                        Id : out Natural; Result : out Status) is
   begin
      Id := 0;
      Result := Invalid_Argument;
      if Description.MMIO_Size /= 0 and then
        not Fits (Description.MMIO_Base, Description.MMIO_Size)
      then return; end if;
      for D of State.Devices loop
         if D.State /= Unused and then D.MMIO_Size /= 0 and then
           Description.MMIO_Size /= 0 and then
           Description.MMIO_Base <= D.MMIO_Base + D.MMIO_Size - 1 and then
           D.MMIO_Base <= Description.MMIO_Base + Description.MMIO_Size - 1
         then Result := Busy; return; end if;
      end loop;
      for I in State.Devices'Range loop
         if State.Devices (I).State = Unused then
            State.Devices (I) := Description;
            State.Devices (I).State := Discovered;
            State.Devices (I).Driver := 0;
            Id := I;
            Result := Success;
            return;
         end if;
      end loop;
      Result := No_Space;
   end Discover;
   procedure Bind (State : in out Manager; Id : Natural; Result : out Status) is
   begin
      Result := Invalid_Argument;
      if Id not in State.Devices'Range then return; end if;
      Result := Busy;
      if State.Devices (Id).State /= Discovered then return; end if;
      for I in State.Drivers'Range loop
         if State.Drivers (I).Active and then
           State.Drivers (I).Class = State.Devices (Id).Class and then
           State.Drivers (I).Vendor = State.Devices (Id).Vendor and then
           State.Drivers (I).Product = State.Devices (Id).Product
         then
            State.Devices (Id).Driver := I;
            State.Devices (Id).State := Bound;
            Result := Success;
            return;
         end if;
      end loop;
      Result := Not_Found;
   end Bind;
end AxiomOS.Drivers.Registry;
