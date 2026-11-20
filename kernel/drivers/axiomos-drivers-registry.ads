package AxiomOS.Drivers.Registry with Preelaborate is
   procedure Register_Driver (State : in out Manager; Class : Device_Class;
                              Vendor, Product : U16; Id : out Natural;
                              Result : out Status;
                              Start : Lifecycle_Action := null;
                              Stop : Lifecycle_Action := null);
   procedure Discover (State : in out Manager; Description : Device;
                        Id : out Natural; Result : out Status);
   procedure Bind (State : in out Manager; Id : Natural; Result : out Status);
end AxiomOS.Drivers.Registry;
