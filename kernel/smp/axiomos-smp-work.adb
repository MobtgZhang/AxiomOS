with AxiomOS.SMP.Locks;
with AxiomOS.HAL.CPU;
with AxiomOS.HAL.Clock;
package body AxiomOS.SMP.Work is
   use type U64, U32;
   type Phase is (Idle, Pending, Executing, Finished);
   type Mailbox is record
      Guard : Locks.Spinlock;
      Enabled : Boolean;
      State : Phase;
      Generation : U32;
      Action : Operation;
      Argument : U64;
      Outcome : Status;
   end record;
   type Mailboxes is array (CPU_Index) of Mailbox;
   Slots : Mailboxes;
   procedure Initialize is
   begin
      for M of Slots loop
         Locks.Initialize (M.Guard);
         M.Enabled := False; M.State := Idle; M.Generation := 0;
         M.Action := null; M.Argument := 0; M.Outcome := Success;
      end loop;
   end Initialize;
   procedure Enable (CPU : CPU_Index) is
   begin
      Locks.Acquire (Slots (CPU).Guard);
      Slots (CPU).Enabled := True;
      Locks.Release (Slots (CPU).Guard);
   end Enable;
   procedure Submit (CPU : CPU_Index; Action : Operation; Argument : U64;
                     Job : out Ticket; Result : out Status) is
      M : Mailbox renames Slots (CPU);
   begin
      Job := Invalid_Ticket; Result := Invalid_Argument;
      if Action = null then return; end if;
      Locks.Acquire (M.Guard);
      if not M.Enabled then Result := Not_Found;
      elsif M.State /= Idle then Result := Busy;
      elsif M.Generation = U32'Last then Result := No_Space;
      else
         M.Generation := M.Generation + 1;
         M.Action := Action; M.Argument := Argument; M.State := Pending;
         Job := Ticket (U64 (M.Generation) * 256 + U64 (CPU) + 1);
         Result := Success;
      end if;
      Locks.Release (M.Guard);
   end Submit;
   procedure Collect (Job : Ticket; Result : out Status; Completed : out Boolean) is
      Id : constant U64 := U64 (Job) mod 256;
   begin
      Result := Bad_Handle; Completed := False;
      if Id = 0 or else Id > Max_CPUs then return; end if;
      declare M : Mailbox renames Slots (CPU_Index (Id - 1));
      begin
         Locks.Acquire (M.Guard);
         if U64 (M.Generation) /= U64 (Job) / 256 or else M.State = Idle then
            Result := Bad_Handle;
         elsif M.State = Finished then
            Result := M.Outcome; Completed := True;
            M.State := Idle; M.Action := null;
         else Result := Would_Block;
         end if;
         Locks.Release (M.Guard);
      end;
   end Collect;
   procedure Wait (Job : Ticket; Timeout_US : U64; Result : out Status) is
      First : constant U64 := HAL.Clock.Now;
      Done : Boolean;
   begin
      loop
         Collect (Job, Result, Done);
         if Done or else Result /= Would_Block then return; end if;
         if HAL.Clock.Now - First >= Timeout_US then Result := Timed_Out; return; end if;
         HAL.CPU.Pause;
      end loop;
   end Wait;
   procedure Serve (CPU : CPU_Index) is
      Action : Operation;
      Argument : U64;
      Outcome : Status;
      M : Mailbox renames Slots (CPU);
   begin
      loop
         Locks.Acquire (M.Guard);
         if M.State = Pending then
            Action := M.Action; Argument := M.Argument; M.State := Executing;
            Locks.Release (M.Guard);
            Action (CPU, Argument, Outcome);
            Locks.Acquire (M.Guard);
            M.Outcome := Outcome; M.State := Finished;
            Locks.Release (M.Guard);
         else
            Locks.Release (M.Guard);
            HAL.CPU.Pause;
         end if;
      end loop;
   end Serve;
end AxiomOS.SMP.Work;
