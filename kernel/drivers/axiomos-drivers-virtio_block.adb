with AxiomOS.Drivers.PCI;
with AxiomOS.HAL.CPU;
with AxiomOS.Raw;
package body AxiomOS.Drivers.Virtio_Block is
   use type U8, U16, U32, U64;
   Common, Notify, DMA, Length : U64;
   Available_Index, Used_Index : U16;
   Ready : Boolean;
   function Capacity return U64 is (Length);
   function Common_Address return U64 is (Common);
   function Notify_Address return U64 is (Notify);
   procedure Initialize (Info : Boot.Protocol.Boot_Info;
                         Pages : in out Memory.Physical.Allocator; Result : out Status) is
      Config, Device_Config : U64;
      Multiplier : U32;
   begin
      Ready := False; Length := 0; Available_Index := 0; Used_Index := 0;
      PCI.Find_Virtio_Block (Info, Config, Common, Notify, Device_Config, Multiplier, Result);
      if Result /= Success then return; end if;
      Raw.Store8 (Common + 20, 0);
      Raw.Store8 (Common + 20, 1); Raw.Store8 (Common + 20, 3);
      Raw.Store32 (Common, 1);
      if (Raw.Load32 (Common + 4) and 1) = 0 then Result := Unsupported; return; end if;
      Raw.Store32 (Common + 8, 0); Raw.Store32 (Common + 12, 0);
      Raw.Store32 (Common + 8, 1); Raw.Store32 (Common + 12, 1);
      Raw.Store8 (Common + 20, 11);
      if (Raw.Load8 (Common + 20) and 8) = 0 then Result := Unsupported; return; end if;
      Raw.Store16 (Common + 22, 0);
      if Raw.Load16 (Common + 24) < 8 then Result := Unsupported; return; end if;
      Raw.Store16 (Common + 24, 8);
      Notify := Notify + U64 (Raw.Load16 (Common + 30)) * U64 (Multiplier);
      Memory.Physical.Allocate (Pages, 3, 4096, Memory.Physical.DMA, DMA, Result);
      if Result /= Success then return; end if;
      Raw.Zero (DMA, 3 * 4096);
      Raw.Store16 (DMA + 128, 1); -- avail: suppress interrupts, poll used ring
      Raw.Store64 (Common + 32, DMA);
      Raw.Store64 (Common + 40, DMA + 128);
      Raw.Store64 (Common + 48, DMA + 256);
      Raw.Store16 (Common + 26, 16#FFFF#);
      Raw.Store16 (Common + 28, 1);
      Length := Raw.Load64 (Device_Config);
      if Length > U64'Last / 512 then Result := Corrupt; return; end if;
      Length := Length * 512;
      if Length < 1024 then Result := Corrupt; return; end if;
      HAL.CPU.Fence;
      Raw.Store8 (Common + 20, 15);
      Ready := True; Result := Success;
   end Initialize;
   procedure Sector (LBA : U64; Result : out Status) is
      Start_Time : U64;
   begin
      Raw.Store32 (DMA + 512, 0); -- VIRTIO_BLK_T_IN
      Raw.Store32 (DMA + 516, 0); Raw.Store64 (DMA + 520, LBA);
      Raw.Store8 (DMA + 544, 16#FF#);
      Raw.Store64 (DMA, DMA + 512); Raw.Store32 (DMA + 8, 16);
      Raw.Store16 (DMA + 12, 1); Raw.Store16 (DMA + 14, 1);
      Raw.Store64 (DMA + 16, DMA + 4096); Raw.Store32 (DMA + 24, 512);
      Raw.Store16 (DMA + 28, 3); Raw.Store16 (DMA + 30, 2);
      Raw.Store64 (DMA + 32, DMA + 544); Raw.Store32 (DMA + 40, 1);
      Raw.Store16 (DMA + 44, 2); Raw.Store16 (DMA + 46, 0);
      Raw.Store16 (DMA + 132 + U64 (Available_Index mod 8) * 2, 0);
      HAL.CPU.Fence;
      Available_Index := Available_Index + 1;
      Raw.Store16 (DMA + 130, Available_Index);
      HAL.CPU.Fence; Raw.Store16 (Notify, 0);
      Start_Time := HAL.CPU.Ticks;
      while Raw.Load16 (DMA + 258) = Used_Index loop
         if HAL.CPU.Ticks - Start_Time > 500_000_000 then Ready := False; Result := Timed_Out; return; end if;
         HAL.CPU.Pause;
      end loop;
      HAL.CPU.Fence;
      if Raw.Load16 (DMA + 258) /= Used_Index + 1 or else
        Raw.Load32 (DMA + 260 + U64 (Used_Index mod 8) * 8) /= 0 then
         Ready := False; Result := Corrupt; return;
      end if;
      Used_Index := Used_Index + 1;
      if Raw.Load8 (DMA + 544) /= 0 then Result := IO_Error;
      else Result := Success; end if;
   end Sector;
   procedure Read (Offset : U64; Buffer : out Bytes; Result : out Status) is
      Cursor : U64 := Offset;
      Done, Count : Natural := 0;
   begin
      Buffer := (others => 0); Result := IO_Error;
      if not Ready then return; end if;
      Result := Invalid_Argument;
      if Offset > Length or else U64 (Buffer'Length) > Length - Offset then return; end if;
      while Done < Buffer'Length loop
         Sector (Cursor / 512, Result);
         if Result /= Success then return; end if;
         Count := Natural'Min (512 - Natural (Cursor mod 512), Buffer'Length - Done);
         Raw.Copy (Raw.Number (Buffer'Address) + U64 (Done), DMA + 4096 + Cursor mod 512, U64 (Count));
         Done := Done + Count; Cursor := Cursor + U64 (Count);
      end loop;
      Result := Success;
   end Read;
end AxiomOS.Drivers.Virtio_Block;
