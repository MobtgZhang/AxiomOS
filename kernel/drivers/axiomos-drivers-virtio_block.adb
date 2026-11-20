with AxiomOS.Drivers.PCI;
with AxiomOS.HAL.CPU;
with AxiomOS.HAL.Clock;
with AxiomOS.SMP.Locks;
with AxiomOS.Raw;
package body AxiomOS.Drivers.Virtio_Block is
   use type U8, U16, U32, U64;
   Common, Notify, DMA, Length : U64;
   Available_Index, Used_Index : U16;
   Ready : Boolean;
   Queue_Lock : SMP.Locks.Spinlock;
   function Capacity return U64 is (Length);
   function Common_Address return U64 is (Common);
   function Notify_Address return U64 is (Notify);
   procedure Reset (Result : out Status) is
      First : constant U64 := HAL.Clock.Now;
   begin
      Ready := False;
      if Common = 0 then Result := Success; return; end if;
      Raw.Store8 (Common + 20, 0); HAL.CPU.Fence;
      while Raw.Load8 (Common + 20) /= 0 loop
         if HAL.Clock.Now - First >= 1_000_000 then Result := Timed_Out; return; end if;
         HAL.CPU.Pause;
      end loop;
      HAL.CPU.Fence; Result := Success;
   end Reset;
   procedure Shutdown (Pages : in out Memory.Physical.Allocator; Result : out Status) is
   begin
      SMP.Locks.Acquire (Queue_Lock);
      Reset (Result);
      if Result = Success then
         if DMA /= 0 then
            Memory.Physical.Release (Pages, DMA, 3, Result);
            if Result = Success then DMA := 0; end if;
         end if;
         Length := 0;
      end if;
      SMP.Locks.Release (Queue_Lock);
   end Shutdown;
   procedure Initialize (Info : Boot.Protocol.Boot_Info;
                         Pages : in out Memory.Physical.Allocator; Result : out Status) is
      Config, Device_Config, Notify_Size, Notify_Offset : U64;
      Multiplier : U32;
      Generation : U8;
      Stable : Boolean := False;
      procedure Fail (Error : Status) is
         S : Status;
      begin
         Reset (S);
         if S = Success and then DMA /= 0 then
            Memory.Physical.Release (Pages, DMA, 3, S);
            if S = Success then DMA := 0; end if;
         end if;
         Length := 0; Result := Error;
      end Fail;
   begin
      if DMA /= 0 then Result := Busy; return; end if;
      SMP.Locks.Initialize (Queue_Lock);
      Ready := False; Length := 0; Available_Index := 0; Used_Index := 0;
      PCI.Find_Virtio_Block (Info, Config, Common, Notify, Device_Config, Multiplier, Notify_Size, Result);
      if Result /= Success then return; end if;
      Reset (Result);
      if Result /= Success then return; end if;
      Raw.Store8 (Common + 20, 1); Raw.Store8 (Common + 20, 3);
      Raw.Store32 (Common, 1);
      if (Raw.Load32 (Common + 4) and 1) = 0 then Fail (Unsupported); return; end if;
      Raw.Store32 (Common + 8, 0); Raw.Store32 (Common + 12, 0);
      Raw.Store32 (Common + 8, 1); Raw.Store32 (Common + 12, 1);
      Raw.Store8 (Common + 20, 11);
      if (Raw.Load8 (Common + 20) and 8) = 0 then Fail (Unsupported); return; end if;
      Raw.Store16 (Common + 22, 0);
      if Raw.Load16 (Common + 24) < 8 then Fail (Unsupported); return; end if;
      Raw.Store16 (Common + 24, 8);
      Notify_Offset := U64 (Raw.Load16 (Common + 30)) * U64 (Multiplier);
      if Notify_Offset > Notify_Size - 2 then Fail (Corrupt); return; end if;
      Notify := Notify + Notify_Offset;
      Memory.Physical.Allocate (Pages, 3, 4096, Memory.Physical.DMA, DMA, Result);
      if Result /= Success then return; end if;
      Raw.Zero (DMA, 3 * 4096);
      Raw.Store16 (DMA + 128, 1); -- avail: suppress interrupts, poll used ring
      Raw.Store64 (Common + 32, DMA);
      Raw.Store64 (Common + 40, DMA + 128);
      Raw.Store64 (Common + 48, DMA + 256);
      Raw.Store16 (Common + 26, 16#FFFF#);
      Raw.Store16 (Common + 28, 1);
      -- VirtIO requires config_generation to bracket multiword config reads.
      for Attempt in 1 .. 32 loop
         Generation := Raw.Load8 (Common + 21); HAL.CPU.Fence;
         Length := U64 (Raw.Load32 (Device_Config)) + U64 (Raw.Load32 (Device_Config + 4)) * 2 ** 32;
         HAL.CPU.Fence;
         if Generation = Raw.Load8 (Common + 21) then Stable := True; exit; end if;
      end loop;
      if not Stable then Fail (Busy); return; end if;
      if Length > U64'Last / 512 then Fail (Corrupt); return; end if;
      Length := Length * 512;
      if Length < 1024 then Fail (Corrupt); return; end if;
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
      Start_Time := HAL.Clock.Now;
      while Raw.Load16 (DMA + 258) = Used_Index loop
         if HAL.Clock.Now - Start_Time >= 5_000_000 then Ready := False; Result := Timed_Out; return; end if;
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
   procedure Read_Locked (Offset : U64; Buffer : out Bytes; Result : out Status) is
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
   end Read_Locked;
   procedure Read (Offset : U64; Buffer : out Bytes; Result : out Status) is
   begin
      SMP.Locks.Acquire (Queue_Lock);
      Read_Locked (Offset, Buffer, Result);
      SMP.Locks.Release (Queue_Lock);
   end Read;
end AxiomOS.Drivers.Virtio_Block;
