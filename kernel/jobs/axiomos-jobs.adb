package body AxiomOS.Jobs is
   use type U32, U64, Process.PID;

   function Resolve (State : Manager; Id : Job_Id) return Natural is
      Slot : constant U64 := U64 (Id) mod 256;
   begin
      if Slot = 0 or else Slot > Max_Jobs or else
        State.Entries (Natural (Slot)).State = Empty or else
        U64 (State.Entries (Natural (Slot)).Generation) /= U64 (Id) / 256
      then
         return 0;
      end if;
      return Natural (Slot);
   end Resolve;

   procedure Initialize (State : in out Manager) is
   begin
      for J of State.Entries loop
         J.State := Empty;
         J.Generation := 1;
         J.Worker := Process.Kernel_PID;
         J.Pages := 0;
         J.Program_Length := 0;
         J.Exit_Code := 0;
         J.Failed_To_Start := False;
      end loop;
      State.Reserved := 0;
   end Initialize;

   procedure Set_Page_Limit (State : in out Manager; Limit : U64) is
   begin
      State.Page_Limit := Limit;
   end Set_Page_Limit;

   function Reserved_Pages (State : Manager) return U64 is
   begin
      return State.Reserved;
   end Reserved_Pages;

   procedure Submit (State : in out Manager; Program : String;
                     Priority : U32; Kind : Job_Class; User_Id : U32;
                     Pages : U64; Id : out Job_Id; Result : out Status) is
   begin
      Id := No_Job;
      Result := Invalid_Argument;
      if Program'Length = 0 or else Program'Length > Max_Program then
         return;
      end if;
      for I in State.Entries'Range loop
         if State.Entries (I).State = Empty and then
           State.Entries (I).Generation /= 0
         then
            declare
               Generation : constant U32 := State.Entries (I).Generation;
            begin
               State.Entries (I) := (State => Held,
                                     Generation => Generation,
                                     Priority => Priority,
                                     Class => Kind,
                                     User_Id => User_Id,
                                     Pages => Pages,
                                     Program => (others => Character'Val (0)),
                                     Program_Length => 0,
                                     Worker => Process.Kernel_PID,
                                     Exit_Code => 0,
                                     Failed_To_Start => False);
               State.Entries (I).Program (1 .. Program'Length) :=
                 Program (Program'First .. Program'First + Program'Length - 1);
               State.Entries (I).Program_Length := Program'Length;
               Id := Job_Id (U64 (Generation) * 256 + U64 (I));
               Result := Success;
               return;
            end;
         end if;
      end loop;
      Result := No_Space;
   end Submit;

   procedure Cancel (State : in out Manager; Id : Job_Id; Result : out Status) is
      I : constant Natural := Resolve (State, Id);
   begin
      Result := Bad_Handle;
      if I = 0 then return; end if;
      Result := Busy;
      if State.Entries (I).State = Running then return; end if;
      if State.Entries (I).State = Admitted then
         State.Reserved := State.Reserved - State.Entries (I).Pages;
      end if;
      State.Entries (I).State := Empty;
      State.Entries (I).Generation := State.Entries (I).Generation + 1;
      State.Entries (I).Pages := 0;
      State.Entries (I).Program_Length := 0;
      Result := Success;
   end Cancel;

   procedure Admit (State : in out Manager; Program : out String;
                    Program_Length : out Natural; Pages : out U64;
                    Id : out Job_Id; Result : out Status) is
      Best : Natural := 0;
      Queued : Boolean := False;
      Fits : Boolean;
   begin
      Program_Length := 0;
      Pages := 0;
      Id := No_Job;
      Result := Invalid_Argument;
      if Program'Length < Max_Program then return; end if;
      for I in State.Entries'Range loop
         if State.Entries (I).State = Held then
            Queued := True;
            Fits := State.Page_Limit = 0 or else
              State.Reserved + State.Entries (I).Pages <= State.Page_Limit;
            if Fits and then
              (Best = 0 or else
               State.Entries (I).Priority > State.Entries (Best).Priority)
            then
               Best := I;
            end if;
         end if;
      end loop;
      if Best = 0 then
         Result := (if Queued then Out_Of_Memory else Not_Found);
         return;
      end if;
      declare
         Job : Job_Record renames State.Entries (Best);
      begin
         Program (Program'First .. Program'First + Job.Program_Length - 1) :=
           Job.Program (1 .. Job.Program_Length);
         Program_Length := Job.Program_Length;
         Pages := Job.Pages;
         Id := Job_Id (U64 (Job.Generation) * 256 + U64 (Best));
         Job.State := Admitted;
         State.Reserved := State.Reserved + Job.Pages;
         Result := Success;
      end;
   end Admit;

   procedure Bind (State : in out Manager; Id : Job_Id;
                   Worker : Process.PID; Result : out Status) is
      I : constant Natural := Resolve (State, Id);
   begin
      Result := Bad_Handle;
      if I = 0 then return; end if;
      Result := Busy;
      if State.Entries (I).State /= Admitted or else
        Worker = Process.Kernel_PID
      then return; end if;
      State.Entries (I).Worker := Worker;
      State.Entries (I).State := Running;
      Result := Success;
   end Bind;

   procedure Complete (State : in out Manager; Id : Job_Id; Code : U32;
                       Result : out Status) is
      I : constant Natural := Resolve (State, Id);
   begin
      Result := Bad_Handle;
      if I = 0 then return; end if;
      Result := Busy;
      if State.Entries (I).State /= Running then return; end if;
      State.Entries (I).Exit_Code := Code;
      State.Entries (I).Failed_To_Start := False;
      State.Entries (I).Worker := Process.Kernel_PID;
      State.Entries (I).State := Done;
      State.Reserved := State.Reserved - State.Entries (I).Pages;
      Result := Success;
   end Complete;

   procedure Fail (State : in out Manager; Id : Job_Id; Result : out Status) is
      I : constant Natural := Resolve (State, Id);
   begin
      Result := Bad_Handle;
      if I = 0 then return; end if;
      Result := Busy;
      if State.Entries (I).State = Empty or else
        State.Entries (I).State = Done
      then return; end if;
      if State.Entries (I).State = Admitted then
         State.Reserved := State.Reserved - State.Entries (I).Pages;
      end if;
      State.Entries (I).Exit_Code := 127;
      State.Entries (I).Failed_To_Start := True;
      State.Entries (I).Worker := Process.Kernel_PID;
      State.Entries (I).State := Done;
      Result := Success;
   end Fail;

   procedure Wait (State : in out Manager; Id : Job_Id; Code : out U32;
                   Result : out Status) is
      I : constant Natural := Resolve (State, Id);
   begin
      Code := 0;
      Result := Bad_Handle;
      if I = 0 then return; end if;
      Result := Would_Block;
      if State.Entries (I).State /= Done then return; end if;
      Code := State.Entries (I).Exit_Code;
      State.Entries (I).State := Empty;
      State.Entries (I).Generation := State.Entries (I).Generation + 1;
      Result := Success;
   end Wait;

   function Count (State : Manager; Kind : Job_State) return Natural is
      Total : Natural := 0;
   begin
      for J of State.Entries loop
         if J.State = Kind then Total := Total + 1; end if;
      end loop;
      return Total;
   end Count;
end AxiomOS.Jobs;
