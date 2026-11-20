with AxiomOS.Types; use AxiomOS.Types;
package AxiomOS.Drivers with Preelaborate is
   Max_Devices : constant := 64;
   type Device_State is (Unused, Discovered, Bound, Running, Failed);
   type Device_Class is (Serial, Block_Device, Network, Input, Display, Other);
   type Device is record
      State : Device_State := Unused;
      Class : Device_Class := Other;
      Vendor, Product : U16 := 0;
      MMIO_Base, MMIO_Size : U64 := 0;
      IRQ : U32 := 0;
      Driver : Natural := 0;
   end record;
   type Device_Array is array (Positive range 1 .. Max_Devices) of Device;
   type Lifecycle_Action is access procedure (Description : Device; Result : out Status);
   type Driver_Record is record
      Active : Boolean := False;
      Class : Device_Class := Other;
      Vendor, Product : U16 := 0;
      Start, Stop : Lifecycle_Action := null;
   end record;
   type Driver_Array is array (Positive range 1 .. 32) of Driver_Record;
   type Manager is record
      Devices : Device_Array;
      Drivers : Driver_Array;
   end record;
end AxiomOS.Drivers;
