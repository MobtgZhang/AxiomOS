with Ada.Text_IO;
with AxiomOS.Types; use AxiomOS.Types;
with AxiomOS.Process.Table;
with AxiomOS.Memory.Virtual;
with AxiomOS.Security.User_Memory;
with AxiomOS.Syscall.Dispatch;
with AxiomOS.IO.Handles;
with AxiomOS.VFS.Tmpfs;
package body Test_Process is
   use AxiomOS;
   use type U64, U32, Process.PID;
   RAM : Bytes (0 .. 8191) := (others => 0);
   Processes : Process.Manager;
   FS : VFS.File_System;
   procedure Copy_In (Caller : Process.Process_Record; Address : U64;
                       Buffer : out Bytes; Result : out Status) is
      Physical : U64;
   begin
      Security.User_Memory.Translate (Caller.Space, Address, U64 (Buffer'Length), False,
                                      Physical, Result);
      if Result /= Success then return; end if;
      if Physical < 16#10000# or else Physical - 16#10000# + U64 (Buffer'Length) > RAM'Length
      then Result := Invalid_Argument; return; end if;
      for J in Buffer'Range loop
         Buffer (J) := RAM (Natural (Physical - 16#10000#) + J - Buffer'First);
      end loop;
   end Copy_In;
   procedure Copy_Out (Caller : Process.Process_Record; Address : U64;
                        Buffer : Bytes; Result : out Status) is
      Physical : U64;
   begin
      Security.User_Memory.Translate (Caller.Space, Address, U64 (Buffer'Length), True,
                                      Physical, Result);
      if Result /= Success then return; end if;
      if Physical < 16#10000# or else Physical - 16#10000# + U64 (Buffer'Length) > RAM'Length
      then Result := Invalid_Argument; return; end if;
      for J in Buffer'Range loop
         RAM (Natural (Physical - 16#10000#) + J - Buffer'First) := Buffer (J);
      end loop;
   end Copy_Out;
   package Calls is new Syscall.Dispatch (Copy_In, Copy_Out);
   procedure Run is
      Id, Next : Process.PID;
      Index, N : Natural;
      S : Status;
      H : IO.Handle;
      Reply : Syscall.Return_Value;
      Code : U32;
   begin
      Process.Table.Initialize (Processes);
      VFS.Tmpfs.Initialize (FS);
      VFS.Tmpfs.Create (FS, "/data", VFS.Regular, N, S);
      pragma Assert (S = Success);
      Process.Table.Create (Processes, Process.Kernel_PID, (1000, 1000), Id, S);
      pragma Assert (S = Success);
      Index := Process.Table.Resolve (Processes, Id);
      Memory.Virtual.Map (Processes.Entries (Index).Space, 4096, 16#10000#, 4096,
                          (True, False, True, True, False), S);
      pragma Assert (S = Success);
      Memory.Virtual.Map (Processes.Entries (Index).Space, 8192, 16#11000#, 4096,
                          (True, True, False, True, False), S);
      pragma Assert (S = Success);
      Process.Table.Make_Ready (Processes, Id, 4096, 12_288, S);
      pragma Assert (S = Success);
      Process.Table.Start (Processes, Id, S);
      pragma Assert (S = Success);
      IO.Handles.Open (Processes.Entries (Index).Handles, FS, "/data", (True, True), H, S);
      pragma Assert (S = Success);
      RAM (4096 .. 4098) := (65, 100, 97);
      Calls.Invoke (Processes, Id, FS, 2, (U64 (H), 8192, 3, 0, 0), Reply);
      pragma Assert (Reply.Error = Success and Reply.Value = 3);
      Calls.Invoke (Processes, Id, FS, 1, (U64 (H), 4096, 3, 0, 0), Reply);
      pragma Assert (Reply.Error = Permission_Denied);
      Calls.Invoke (Processes, Id, FS, 2, (U64 (H), U64'Last, 3, 0, 0), Reply);
      pragma Assert (Reply.Error = Permission_Denied);
      Calls.Invoke (Processes, Id, FS, 99, (others => 0), Reply);
      pragma Assert (Reply.Error = Unsupported);
      Process.Table.Wait (Processes, Process.Kernel_PID, Id, Code, S);
      pragma Assert (S = Would_Block);
      Calls.Invoke (Processes, Id, FS, 0, (42, 0, 0, 0, 0), Reply);
      pragma Assert (Reply.Error = Success);
      pragma Assert (FS.Nodes (N).Open_Count = 0);
      pragma Assert (IO.Handles.Resolve (Processes.Entries (Index).Handles, H) = 0);
      Process.Table.Wait (Processes, Process.Kernel_PID, Id, Code, S);
      pragma Assert (S = Success and Code = 42 and Process.Table.Resolve (Processes, Id) = 0);
      Process.Table.Create (Processes, Process.Kernel_PID, (1000, 1000), Next, S);
      pragma Assert (S = Success and Next /= Id);
      Ada.Text_IO.Put_Line ("PASS processes, syscall I/O, user pointers, permissions, exit/wait, stale PID");
   end Run;
end Test_Process;
