with AxiomOS.Kernel.State;
with AxiomOS.Drivers.Registry;
with AxiomOS.Drivers.Lifecycle;
with AxiomOS.Drivers.Virtio_Block;
with AxiomOS.HAL.Console;
with AxiomOS.SMP.Work;
package body AxiomOS.Kernel.Devices is
   use type U64;
   Saved_Info : Boot.Protocol.Boot_Info;
   Expected : Bytes (0 .. 511);
   procedure Start_Block (Description : Drivers.Device; Result : out Status) is
      pragma Unreferenced (Description);
   begin
      if Drivers.Virtio_Block.Capacity /= 0 then Result := Success;
      else Drivers.Virtio_Block.Initialize (Saved_Info, State.Pages, Result); end if;
   end Start_Block;
   procedure Stop_Block (Description : Drivers.Device; Result : out Status) is
      pragma Unreferenced (Description);
   begin Drivers.Virtio_Block.Shutdown (State.Pages, Result); end Stop_Block;
   procedure Initialize (Info : Boot.Protocol.Boot_Info; Result : out Status) is
      Device_Id, Driver_Id, Before : Natural;
      Data : Bytes (0 .. 511);
   begin
      Saved_Info := Info;
      Before := State.Pages.Available;
      Drivers.Virtio_Block.Initialize (Info, State.Pages, Result);
      if Result /= Success then return; end if;
      Drivers.Registry.Register_Driver (State.Devices, Drivers.Block_Device, 16#1AF4#, 16#1042#,
        Driver_Id, Result, Start_Block'Access, Stop_Block'Access);
      if Result /= Success then return; end if;
      Drivers.Registry.Discover (State.Devices,
        (Drivers.Discovered, Drivers.Block_Device, 16#1AF4#, 16#1042#,
         Drivers.Virtio_Block.Common_Address, 56, 0, 0), Device_Id, Result);
      if Result /= Success then return; end if;
      Drivers.Registry.Bind (State.Devices, Device_Id, Result);
      if Result /= Success then return; end if;
      Drivers.Lifecycle.Set_Running (State.Devices, Device_Id, Result);
      if Result /= Success then return; end if;
      Drivers.Virtio_Block.Read (1024, Expected, Result);
      if Result /= Success then return; end if;
      Drivers.Lifecycle.Remove (State.Devices, Device_Id, Result);
      if Result /= Busy then Result := Corrupt; return; end if;
      Drivers.Lifecycle.Stop (State.Devices, Device_Id, Result);
      if Result /= Success then return; end if;
      if State.Pages.Available /= Before then Result := Corrupt; return; end if;
      Drivers.Virtio_Block.Read (1024, Data, Result);
      if Result /= IO_Error then Result := Corrupt; return; end if;
      Drivers.Lifecycle.Set_Running (State.Devices, Device_Id, Result);
      if Result /= Success then return; end if;
      Drivers.Virtio_Block.Read (1024, Data, Result);
      if Result /= Success then return; end if;
      if Data /= Expected then Result := Corrupt; return; end if;
      HAL.Console.Line ("AXIOM:BLOCK:RESET:PASS");
      HAL.Console.Line ("AXIOM:BLOCK:HARDWARE:PASS");
   end Initialize;
   procedure Read_Work (CPU : SMP.CPU_Index; Argument : U64; Result : out Status) is
      pragma Unreferenced (CPU, Argument);
      Data : Bytes (0 .. 511);
   begin
      for I in 1 .. 8 loop
         Drivers.Virtio_Block.Read (1024, Data, Result);
         if Result /= Success then return; end if;
         if Data /= Expected then Result := Corrupt; return; end if;
      end loop;
   end Read_Work;
   procedure Check_Concurrent (Result : out Status) is
      Jobs : array (SMP.CPU_Index) of SMP.Work.Ticket;
   begin
      for I in 1 .. State.CPUs.Count - 1 loop
         SMP.Work.Submit (I, Read_Work'Access, 0, Jobs (I), Result);
         if Result /= Success then return; end if;
      end loop;
      Read_Work (State.CPUs.Bootstrap, 0, Result);
      if Result /= Success then return; end if;
      for I in 1 .. State.CPUs.Count - 1 loop
         SMP.Work.Wait (Jobs (I), 10_000_000, Result);
         if Result /= Success then return; end if;
      end loop;
      HAL.Console.Line ("AXIOM:BLOCK:SMP:PASS");
   end Check_Concurrent;
end AxiomOS.Kernel.Devices;
