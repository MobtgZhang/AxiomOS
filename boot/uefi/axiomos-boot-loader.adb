with Ada.Unchecked_Conversion;
with AxiomOS.Boot.Menu;
with AxiomOS.Boot.Protocol;
with AxiomOS.Boot.Images;
with AxiomOS.Boot.Handoff;
with AxiomOS.Firmware.UEFI;
with AxiomOS.Firmware.UEFI.Files;
with AxiomOS.HAL.Console;
with AxiomOS.HAL.CPU;
with AxiomOS.Architecture;
with AxiomOS.Raw;
package body AxiomOS.Boot.Loader is
   use type U16, U32, U64, Menu.Selection, Menu.Action;
   package EFI renames Firmware.UEFI;
   procedure Show (Choice : Menu.Selection) is
   begin
      EFI.Text (ASCII.CR & ASCII.LF & "AxiomOS / Ada 2022 / " &
                Architecture.Name & ASCII.CR & ASCII.LF &
                "  1. Boot AxiomOS" & ASCII.CR & ASCII.LF &
                "  2. Boot with diagnostics" & ASCII.CR & ASCII.LF &
                "  3. Return to UEFI firmware" & ASCII.CR & ASCII.LF &
                "Arrows: select, Enter: boot, 1/2/3: choose." & ASCII.CR & ASCII.LF &
                "Default starts after 5 seconds. Selected: ");
      case Choice is
         when Menu.Normal_Boot => EFI.Text ("1");
         when Menu.Diagnostics => EFI.Text ("2");
         when Menu.Firmware_Return => EFI.Text ("3");
      end case;
      EFI.Text (ASCII.CR & ASCII.LF);
   end Show;
   function Main (Image, Table : U64) return U64 is
      Choice : Menu.Selection := Menu.Normal_Boot;
      Input : Menu.Action;
      Confirmed, Interactive : Boolean := False;
      Key : EFI.Key;
      S : EFI.EFI_Status;
      Result : Status;
      Info_Base, Kernel_File, Kernel_Length, Entry_Point : U64;
      Info : Protocol.Info_Access;
      Timeout_Ticks : Natural := 0;
      function To_Info is new Ada.Unchecked_Conversion (U64, Protocol.Info_Access);
   begin
      EFI.Configure (Image, Table);
      HAL.Console.Line ("AxiomOS UEFI " & Architecture.Name);
      Show (Choice);
      HAL.Console.Line ("AXIOM:MENU:READY");
      loop
         S := EFI.Read_Key (Key);
         if S = EFI.EFI_Success then
            Input := Menu.No_Action;
            if Key.Unicode = 13 then Input := Menu.Confirm_Choice;
            elsif Key.Unicode = Character'Pos ('1') then Input := Menu.Select_Normal;
            elsif Key.Unicode = Character'Pos ('2') then Input := Menu.Select_Diagnostics;
            elsif Key.Unicode = Character'Pos ('3') then Input := Menu.Select_Firmware;
            elsif Key.Scan_Code = 1 then Input := Menu.Move_Up;
            elsif Key.Scan_Code = 2 then Input := Menu.Move_Down;
            end if;
            Menu.Update (Choice, Input, Confirmed);
            if Input /= Menu.No_Action then Interactive := True; end if;
            exit when Confirmed;
            if Interactive then Show (Choice); end if;
         end if;
         EFI.Stall (10_000);
         Timeout_Ticks := Timeout_Ticks + 1;
         exit when not Interactive and then Timeout_Ticks >= 500;
      end loop;
      if Choice = Menu.Firmware_Return then
         HAL.Console.Line ("AXIOM:MENU:FIRMWARE");
         return 0;
      end if;
      EFI.Text ("Loading Ada kernel and initramfs..." & ASCII.CR & ASCII.LF);
      S := EFI.Allocate_Pages (1, Info_Base);
      if S /= 0 then HAL.Console.Panic ("handoff allocation"); end if;
      Raw.Zero (Info_Base, 4096);
      Info := To_Info (Info_Base);
      Info.all := (others => <>);
      Info.Flags := (if Choice = Menu.Diagnostics then 1 else 0);
      EFI.Files.Load ("\axiomos\kernel.elf", Kernel_File, Kernel_Length, Result);
      if Result /= Success then HAL.Console.Panic ("kernel.elf read"); end if;
      Images.Load_Kernel (Kernel_File, Kernel_Length,
                          Info.Kernel_Base, Info.Kernel_Size, Entry_Point, Result);
      if Result /= Success then HAL.Console.Panic ("ELF validation or relocation"); end if;
      S := EFI.Free_Pool (Kernel_File);
      EFI.Files.Load ("\axiomos\initramfs.tar", Info.Initramfs_Base,
                       Info.Initramfs_Size, Result);
      if Result /= Success then HAL.Console.Panic ("initramfs read"); end if;
      S := EFI.Allocate_Pages (256, Info.Stack_Base);
      if S /= 0 then HAL.Console.Panic ("kernel stack allocation"); end if;
      Info.Stack_Size := 256 * Page_Size;
      Handoff.Discover_Tables (Info.all);
      Handoff.Leave_Firmware (Info.all, Result);
      if Result /= Success then HAL.Console.Panic ("ExitBootServices"); end if;
      HAL.CPU.Disable_Interrupts;
      HAL.Console.Line ("AXIOM:UEFI:EXITED");
      HAL.CPU.Handoff (Entry_Point, Info_Base, Info.Stack_Base + Info.Stack_Size);
   end Main;
end AxiomOS.Boot.Loader;
