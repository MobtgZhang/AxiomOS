with AxiomOS.Architecture;
with AxiomOS.Boot.Protocol;
with AxiomOS.HAL.Console;
with AxiomOS.HAL.CPU;
with AxiomOS.HAL.SMP;
with AxiomOS.Kernel.State;
with AxiomOS.Kernel.Selftest;
with AxiomOS.Kernel.Users;
with AxiomOS.Memory.Bootstrap;
with AxiomOS.VFS.Tmpfs;
with AxiomOS.VFS.Ustar;
with AxiomOS.Raw;
with AxiomOS.Drivers.Virtio_Block;
with AxiomOS.Drivers.Registry;
with AxiomOS.Drivers.Lifecycle;
with AxiomOS.VFS.Mounts;
with AxiomOS.Storage;
package body AxiomOS.Kernel.Main is
   use type U64, Storage.Format;
   procedure Entry_Point (Info_Address : U64) is
      Info : Boot.Protocol.Boot_Info
        with Import, Address => Raw.Address (Info_Address);
      S : Status;
      Device_Id, Driver_Id : Natural;
   begin
      HAL.CPU.Disable_Interrupts;
      HAL.Console.Line ("AXIOM:KERNEL:ENTER " & Architecture.Name);
      if not Boot.Protocol.Valid (Info) then HAL.Console.Panic ("Boot_Info ABI"); end if;
      State.Initialize;
      Memory.Bootstrap.Import_Map (Info, State.Pages, S);
      if S /= Success then HAL.Console.Panic ("physical memory map"); end if;
      HAL.Console.Put ("AxiomOS usable pages: ");
      HAL.Console.Hex (U64 (State.Pages.Available));
      HAL.Console.Line ("");
      VFS.Tmpfs.Initialize (State.Files);
      if Info.Initramfs_Size = 0 or else Info.Initramfs_Size > 8 * 1024 * 1024
      then HAL.Console.Panic ("initramfs size"); end if;
      declare
         Archive : Bytes (0 .. Natural (Info.Initramfs_Size) - 1)
           with Import, Address => Raw.Address (Info.Initramfs_Base);
      begin
         VFS.Ustar.Mount_Ustar (State.Files, Archive, S);
      end;
      if S /= Success then HAL.Console.Panic ("initramfs corrupt"); end if;
      Selftest.Run (Info);
      Drivers.Virtio_Block.Initialize (Info, State.Pages, S);
      if S /= Success then
         HAL.Console.Put ("block status="); HAL.Console.Hex (U64 (Status'Pos (S)));
         HAL.Console.Panic ("VirtIO block initialization");
      end if;
      Drivers.Registry.Register_Driver (State.Devices, Drivers.Block_Device, 16#1AF4#, 16#1042#, Driver_Id, S);
      if S /= Success then HAL.Console.Panic ("block driver registration"); end if;
      Drivers.Registry.Discover (State.Devices,
        (Drivers.Discovered, Drivers.Block_Device, 16#1AF4#, 16#1042#,
         Drivers.Virtio_Block.Common_Address, 56, 0, 0), Device_Id, S);
      if S /= Success then HAL.Console.Panic ("block device resources"); end if;
      Drivers.Registry.Bind (State.Devices, Device_Id, S);
      if S /= Success then HAL.Console.Panic ("block driver bind"); end if;
      Drivers.Lifecycle.Set_Running (State.Devices, Device_Id, S);
      if S /= Success then HAL.Console.Panic ("block driver lifecycle"); end if;
      HAL.Console.Line ("AXIOM:BLOCK:HARDWARE:PASS");
      VFS.Mounts.Mount_Root (State.Files,
        (Drivers.Virtio_Block.Read'Access, 0, Drivers.Virtio_Block.Capacity), S);
      if S /= Success or else State.Files.Root_Volume.Kind /= Storage.EXT4 then
         HAL.Console.Put ("mount status="); HAL.Console.Hex (U64 (Status'Pos (S)));
         HAL.Console.Panic ("EXT4 root mount");
      end if;
      HAL.Console.Line ("AXIOM:ROOT:EXT4:PASS");
      HAL.SMP.Initialize (Info, State.Pages, State.CPUs, S);
      if S = Unsupported then
         HAL.Console.Line ("AXIOM:SMP:HARDWARE:UNSUPPORTED");
      elsif S /= Success then HAL.Console.Panic ("SMP startup");
      end if;
      Users.Run (Info, S);
      if S = Unsupported then
         HAL.Console.Line ("AXIOM:USER:HARDWARE:UNSUPPORTED");
      elsif S /= Success then
         HAL.Console.Put ("user status="); HAL.Console.Hex (U64 (Status'Pos (S)));
         HAL.Console.Panic ("user runtime");
      end if;
      HAL.Console.Line ("AXIOM:KERNEL:READY");
      HAL.CPU.Halt;
   end Entry_Point;
end AxiomOS.Kernel.Main;
