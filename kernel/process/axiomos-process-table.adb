package body AxiomOS.Process.Table is
   use type U64, U32;
   procedure Initialize (State : in out Manager) is
   begin
      for P of State.Entries loop P := (others => <>); end loop;
   end Initialize;
   function Resolve (State : Manager; Id : PID) return Natural is
      Slot : constant U64 := U64 (Id) mod 256;
   begin
      if Slot = 0 or else Slot > Max_Processes or else
        State.Entries (Natural (Slot)).State = Unused or else
        U64 (State.Entries (Natural (Slot)).Generation) /= U64 (Id) / 256
      then return 0; end if;
      return Natural (Slot);
   end Resolve;
   procedure Create (State : in out Manager; Parent : PID; Identity : Credentials;
                     Id : out PID; Result : out Status) is
   begin
      Id := Kernel_PID;
      if Parent /= Kernel_PID and then Resolve (State, Parent) = 0 then
         Result := Not_Found; return;
      end if;
      for I in State.Entries'Range loop
         if State.Entries (I).State = Unused and then
           State.Entries (I).Generation /= 0
         then
            declare
               Generation : constant U32 := State.Entries (I).Generation;
            begin
               State.Entries (I) := (others => <>);
               State.Entries (I).Generation := Generation;
               State.Entries (I).State := Created;
               State.Entries (I).Parent := Parent;
               State.Entries (I).Identity := Identity;
               Id := PID (U64 (Generation) * 256 + U64 (I));
               Result := Success;
               return;
            end;
         end if;
      end loop;
      Result := No_Space;
   end Create;
   procedure Make_Ready (State : in out Manager; Id : PID; Entry_Point,
                         Stack_Top : U64; Result : out Status) is
      I : constant Natural := Resolve (State, Id);
      Executable : Boolean := False;
   begin
      Result := Bad_Handle;
      if I = 0 then return; end if;
      Result := Invalid_Argument;
      if State.Entries (I).State /= Created or else Stack_Top < 16 or else
        not Aligned (Stack_Top, 16) or else
        not Memory.Virtual.Check_User (State.Entries (I).Space, Stack_Top - 16, 16, True)
      then return; end if;
      for M of State.Entries (I).Space.Entries loop
         if M.Active and then M.Access_Rights.User and then M.Access_Rights.Executable
           and then Entry_Point >= M.Virtual_Base and then
           Entry_Point - M.Virtual_Base < M.Length
         then Executable := True; end if;
      end loop;
      if not Executable then return; end if;
      State.Entries (I).Entry_Point := Entry_Point;
      State.Entries (I).Stack_Top := Stack_Top;
      State.Entries (I).State := Ready;
      Result := Success;
   end Make_Ready;
   procedure Start (State : in out Manager; Id : PID; Result : out Status) is
      I : constant Natural := Resolve (State, Id);
   begin
      Result := Bad_Handle;
      if I = 0 then return; end if;
      Result := Busy;
      if State.Entries (I).State /= Ready then return; end if;
      State.Entries (I).State := Running;
      Result := Success;
   end Start;
   procedure Exit_Process (State : in out Manager; Id : PID; Code : U32;
                           Result : out Status) is
      I : constant Natural := Resolve (State, Id);
   begin
      Result := Bad_Handle;
      if I = 0 then return; end if;
      Result := Busy;
      if State.Entries (I).State = Zombie then return; end if;
      State.Entries (I).Exit_Code := Code;
      State.Entries (I).Handles := (others => <>);
      State.Entries (I).State := Zombie;
      Result := Success;
   end Exit_Process;
   procedure Wait (State : in out Manager; Parent, Child : PID;
                   Code : out U32; Result : out Status) is
      I : constant Natural := Resolve (State, Child);
   begin
      Code := 0;
      Result := Bad_Handle;
      if I = 0 then return; end if;
      Result := Permission_Denied;
      if State.Entries (I).Parent /= Parent then return; end if;
      Result := Would_Block;
      if State.Entries (I).State /= Zombie then return; end if;
      Code := State.Entries (I).Exit_Code;
      State.Entries (I).State := Unused;
      State.Entries (I).Generation := State.Entries (I).Generation + 1;
      Result := Success;
   end Wait;
end AxiomOS.Process.Table;
