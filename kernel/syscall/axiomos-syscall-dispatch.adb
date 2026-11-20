with AxiomOS.Process.Table;
with AxiomOS.IO.Handles;
with AxiomOS.IO.Streams;
with AxiomOS.Memory.Virtual;
with Ada.Unchecked_Conversion;
package body AxiomOS.Syscall.Dispatch is
   use type U64, U8, AxiomOS.Process.Lifecycle;
   function Signed is new Ada.Unchecked_Conversion (U64, I64);
   procedure Invoke (Processes : in out AxiomOS.Process.Manager;
                     Caller : AxiomOS.Process.PID;
                     Files : in out AxiomOS.VFS.File_System;
                     Number : U64; Args : Arguments; Reply : out Return_Value) is
      I : constant Natural := AxiomOS.Process.Table.Resolve (Processes, Caller);
      Count : Natural := 0;
      H : IO.Handle;
      Buffer : Bytes (0 .. 4095);
      Path : String (1 .. 127);
      Length : Natural;
   begin
      Reply := (0, Bad_Handle);
      if I = 0 then return; end if;
      if Processes.Entries (I).State /= AxiomOS.Process.Running then
         Reply.Error := Busy; return;
      end if;
      case Number is
         when 0 =>
            AxiomOS.Process.Table.Exit_Process
              (Processes, Caller, Files, U32 (Args (0) mod 2 ** 32), Reply.Error);
         when 1 | 2 =>
            Reply.Error := Invalid_Argument;
            if Args (2) > Buffer'Length then return; end if;
            if Args (2) = 0 then Reply.Error := Success; return; end if;
            Length := Natural (Args (2));
            Reply.Error := Permission_Denied;
            if not Memory.Virtual.Check_User
              (Processes.Entries (I).Space, Args (1), Args (2), Number = 1)
            then return; end if;
            if Number = 1 then
               -- Validate before consuming the stream. The BSP exclusively
               -- owns the current process and its mappings during dispatch.
               IO.Streams.Read (Processes.Entries (I).Handles, Files,
                 IO.Handle (Args (0)), Buffer (0 .. Length - 1), Count, Reply.Error);
               if Reply.Error = Success and then Count > 0 then
                  Copy_Out (Processes.Entries (I), Args (1), Buffer (0 .. Count - 1), Reply.Error);
               end if;
            else
               Copy_In (Processes.Entries (I), Args (1), Buffer (0 .. Length - 1), Reply.Error);
               if Reply.Error = Success then
                  IO.Streams.Write (Processes.Entries (I).Handles, Files,
                    IO.Handle (Args (0)), Buffer (0 .. Length - 1), Count, Reply.Error);
               end if;
            end if;
            if Reply.Error = Success then Reply.Value := U64 (Count); end if;
         when 3 =>
            Reply.Error := Invalid_Argument;
            if Args (1) = 0 or else Args (1) > 127 or else Args (2) > 3 then return; end if;
            Length := Natural (Args (1));
            Copy_In (Processes.Entries (I), Args (0), Buffer (0 .. Length - 1), Reply.Error);
            if Reply.Error /= Success then return; end if;
            for J in 1 .. Length loop
               if Buffer (J - 1) = 0 then Reply.Error := Invalid_Argument; return; end if;
               Path (J) := Character'Val (Buffer (J - 1));
            end loop;
            IO.Handles.Open (Processes.Entries (I).Handles, Files, Path (1 .. Length),
              ((Args (2) and 1) /= 0, (Args (2) and 2) /= 0), H, Reply.Error);
            if Reply.Error = Success then Reply.Value := U64 (H); end if;
         when 4 =>
            IO.Handles.Close (Processes.Entries (I).Handles, Files, IO.Handle (Args (0)), Reply.Error);
         when 6 =>
            declare Code : U32;
            begin
               AxiomOS.Process.Table.Wait (Processes, Caller, AxiomOS.Process.PID (Args (0)),
                                            Code, Reply.Error);
               Reply.Value := U64 (Code);
            end;
         when 14 =>
            Reply.Error := Invalid_Argument;
            if Args (2) > 2 then return; end if;
            IO.Streams.Seek (Processes.Entries (I).Handles, Files, IO.Handle (Args (0)),
              Signed (Args (1)), IO.Streams.Seek_Origin'Val (Args (2)), Reply.Value, Reply.Error);
         when 15 =>
            declare Kind : VFS.Node_Kind;
            begin
               IO.Streams.Stat (Processes.Entries (I).Handles, Files, IO.Handle (Args (0)),
                 Reply.Value, Kind, Reply.Error);
            end;
         when 16 =>
            Reply.Error := Invalid_Argument;
            if Args (1) > 3 then return; end if;
            IO.Handles.Duplicate (Processes.Entries (I).Handles, Files, IO.Handle (Args (0)),
              ((Args (1) and 1) /= 0, (Args (1) and 2) /= 0), H, Reply.Error);
            if Reply.Error = Success then Reply.Value := U64 (H); end if;
         when others => Reply.Error := Unsupported;
      end case;
   end Invoke;
end AxiomOS.Syscall.Dispatch;
