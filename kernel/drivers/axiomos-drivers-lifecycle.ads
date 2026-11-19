package AxiomOS.Drivers.Lifecycle with Preelaborate is
   procedure Set_Running (State : in out Manager; Id : Natural;
                          Result : out Status);
   procedure Remove (State : in out Manager; Id : Natural; Result : out Status);
end AxiomOS.Drivers.Lifecycle;
