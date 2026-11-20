--  Job management: the classic fifth manager, mapped onto the kernel
--  process model.
--
--  A job is a submitted program plus its resource estimate. Submission
--  places it in the bounded backing queue (Held). The job scheduler admits
--  jobs by priority with FIFO order among equals, reserving the estimated
--  pages against a configurable budget. The loader binds an admitted job to
--  a process; completion or start failure records the exit code for the
--  collector. All state is bounded and static: no allocator, no runtime.
with AxiomOS.Types; use AxiomOS.Types;
with AxiomOS.Process;
package AxiomOS.Jobs with Preelaborate is
   Max_Jobs : constant := 8;
   Max_Program : constant := 31;

   type Job_Id is new U64;
   No_Job : constant Job_Id := 0;

   type Job_State is (Empty, Held, Admitted, Running, Done);
   type Job_Class is (System, Interactive, Batch);

   type Job_Record is record
      State : Job_State := Empty;
      Generation : U32 := 0;
      Priority : U32 := 0;
      Class : Job_Class := Batch;
      User_Id : U32 := 0;
      Pages : U64 := 0;             -- estimate reserved while admitted
      Program : String (1 .. Max_Program) := (others => Character'Val (0));
      Program_Length : Natural := 0;
      Worker : Process.PID := Process.Kernel_PID;
      Exit_Code : U32 := 0;
      Failed_To_Start : Boolean := False;
   end record;

   type Job_Array is array (Positive range 1 .. Max_Jobs) of Job_Record;
   type Manager is limited record
      Entries : Job_Array;
      Page_Limit : U64 := 0;   -- 0 means no page budget
      Reserved : U64 := 0;     -- pages held by admitted/running jobs
   end record;

   procedure Initialize (State : in out Manager);
   procedure Set_Page_Limit (State : in out Manager; Limit : U64);
   function Reserved_Pages (State : Manager) return U64;
   procedure Submit (State : in out Manager; Program : String;
                     Priority : U32; Kind : Job_Class; User_Id : U32;
                     Pages : U64; Id : out Job_Id; Result : out Status);
   procedure Cancel (State : in out Manager; Id : Job_Id; Result : out Status);
   --  Select the highest-priority Held job that fits the page budget and
   --  return its program path and page estimate. Not_Found when the queue
   --  is empty, Out_Of_Memory when every queued job exceeds the budget.
   procedure Admit (State : in out Manager; Program : out String;
                    Program_Length : out Natural; Pages : out U64;
                    Id : out Job_Id; Result : out Status);
   procedure Bind (State : in out Manager; Id : Job_Id;
                   Worker : Process.PID; Result : out Status);
   procedure Complete (State : in out Manager; Id : Job_Id; Code : U32;
                       Result : out Status);
   --  Mark an admitted/running job as started-but-failed (exit code 127).
   procedure Fail (State : in out Manager; Id : Job_Id; Result : out Status);
   --  Collect a finished job and free its slot for the next generation.
   procedure Wait (State : in out Manager; Id : Job_Id; Code : out U32;
                   Result : out Status);
   function Resolve (State : Manager; Id : Job_Id) return Natural;
   function Count (State : Manager; Kind : Job_State) return Natural;
end AxiomOS.Jobs;
