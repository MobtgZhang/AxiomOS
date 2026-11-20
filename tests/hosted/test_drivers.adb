with Ada.Text_IO;
with AxiomOS.Types; use AxiomOS.Types;
with AxiomOS.Drivers.Registry;
with AxiomOS.Drivers.Lifecycle;
package body Test_Drivers is
   use AxiomOS;
   use type Drivers.Device_State;
   Owned : Boolean := False;
   Fail_Stop : Boolean := False;
   procedure Start (Description : Drivers.Device; Result : out Status) is
      pragma Unreferenced (Description);
   begin
      pragma Assert (not Owned); Owned := True; Result := Success;
   end Start;
   procedure Stop (Description : Drivers.Device; Result : out Status) is
      pragma Unreferenced (Description);
   begin
      pragma Assert (Owned);
      if Fail_Stop then Result := Timed_Out;
      else Owned := False; Result := Success; end if;
   end Stop;
   procedure Run is
      State : Drivers.Manager;
      Driver, Id, Other : Natural;
      S : Status;
   begin
      Drivers.Registry.Register_Driver (State, Drivers.Block_Device, 1, 2, Driver, S, Start'Access, Stop'Access);
      pragma Assert (S = Success);
      Drivers.Registry.Discover (State, (Drivers.Discovered, Drivers.Block_Device, 1, 2, 4096, 4096, 0, 0), Id, S);
      Drivers.Registry.Bind (State, Id, S);
      Drivers.Lifecycle.Set_Running (State, Id, S);
      pragma Assert (S = Success and Owned);
      Drivers.Lifecycle.Remove (State, Id, S);
      pragma Assert (S = Busy and Owned);
      Fail_Stop := True;
      Drivers.Lifecycle.Stop (State, Id, S);
      pragma Assert (S = Timed_Out and State.Devices (Id).State = Drivers.Running and Owned);
      Drivers.Registry.Discover (State, (Drivers.Discovered, Drivers.Block_Device, 1, 2, 4096, 4096, 0, 0), Other, S);
      pragma Assert (S = Busy);
      Fail_Stop := False;
      Drivers.Lifecycle.Stop (State, Id, S);
      pragma Assert (S = Success and not Owned);
      Drivers.Lifecycle.Remove (State, Id, S);
      pragma Assert (S = Success);
      Drivers.Registry.Discover (State, (Drivers.Discovered, Drivers.Block_Device, 1, 2, 4096, 4096, 0, 0), Other, S);
      pragma Assert (S = Success);
      Ada.Text_IO.Put_Line ("PASS driver stop failure, resource pinning, quiesce and removal");
   end Run;
end Test_Drivers;
