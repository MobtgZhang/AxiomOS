with Ada.Text_IO;
with AxiomOS.Types; use AxiomOS.Types;
with AxiomOS.Process;
with AxiomOS.Jobs;
package body Test_Jobs is
   use AxiomOS;
   use type U32, U64, Jobs.Job_Id;

   procedure Run is
      State : Jobs.Manager;
      Program : String (1 .. Jobs.Max_Program);
      Program_Length : Natural;
      Pages : U64;
      First, Second, Third, Huge : Jobs.Job_Id;
      Worker : constant Process.PID := Process.PID (5 * 256 + 3);
      Code : U32;
      S : Status;
   begin
      Jobs.Initialize (State);
      pragma Assert (Jobs.Count (State, Jobs.Empty) = Jobs.Max_Jobs);
      pragma Assert (Jobs.Reserved_Pages (State) = 0);

      --  Longest accepted program name and rejection beyond the bound.
      Jobs.Submit (State, "/bin/tool-that-has-exactly-31ch", 0, Jobs.Batch, 1000, 4,
                   First, S);
      pragma Assert (S = Success and First /= Jobs.No_Job);
      Jobs.Submit (State, "/bin/way-too-long-program-name-exceeds", 0, Jobs.Batch, 1000,
                   1, Second, S);
      pragma Assert (S = Invalid_Argument and Second = Jobs.No_Job);
      pragma Assert (Jobs.Count (State, Jobs.Held) = 1);

      Jobs.Submit (State, "/bin/low", 1, Jobs.Batch, 1000, 2, Second, S);
      pragma Assert (S = Success);
      Jobs.Submit (State, "/bin/high", 9, Jobs.Interactive, 1000, 4, Third, S);
      pragma Assert (S = Success);
      Jobs.Submit (State, "/bin/huge", 5, Jobs.Batch, 1000, 100, Huge, S);
      pragma Assert (S = Success);

      --  Page budget: priority order first, then the over-budget job is
      --  skipped while smaller jobs still fit.
      Jobs.Set_Page_Limit (State, 16);
      Jobs.Admit (State, Program, Program_Length, Pages, First, S);
      pragma Assert (S = Success and Program (1 .. Program_Length) = "/bin/high");
      pragma Assert (Pages = 4 and First = Third);
      pragma Assert (Jobs.Reserved_Pages (State) = 4);
      Jobs.Admit (State, Program, Program_Length, Pages, Second, S);
      pragma Assert (S = Success and Program (1 .. Program_Length) = "/bin/low");
      pragma Assert (Jobs.Reserved_Pages (State) = 6);
      Jobs.Admit (State, Program, Program_Length, Pages, First, S);
      pragma Assert (S = Success and
                     Program (1 .. Program_Length) = "/bin/tool-that-has-exactly-31ch");
      pragma Assert (Jobs.Reserved_Pages (State) = 10);
      --  Only the over-budget job remains queued now.
      Jobs.Admit (State, Program, Program_Length, Pages, Huge, S);
      pragma Assert (S = Out_Of_Memory);
      pragma Assert (Program_Length = 0 and Pages = 0 and Huge = Jobs.No_Job);
      pragma Assert (Jobs.Count (State, Jobs.Admitted) = 3);

      Jobs.Bind (State, First, Worker, S);
      pragma Assert (S = Success);
      Jobs.Bind (State, First, Worker, S);
      pragma Assert (S = Busy); -- already running
      Jobs.Bind (State, Jobs.No_Job, Worker, S);
      pragma Assert (S = Bad_Handle);
      pragma Assert (Jobs.Count (State, Jobs.Running) = 1);

      Jobs.Complete (State, First, 42, S);
      pragma Assert (S = Success and Jobs.Reserved_Pages (State) = 6);
      Jobs.Complete (State, First, 42, S);
      pragma Assert (S = Busy);

      --  The admitted-but-never-started job fails at the loader and is
      --  collected with the failure exit code.
      Jobs.Fail (State, Second, S);
      pragma Assert (S = Success and Jobs.Reserved_Pages (State) = 4);
      Jobs.Wait (State, Second, Code, S);
      pragma Assert (S = Success and Code = 127);
      Jobs.Wait (State, Second, Code, S);
      pragma Assert (S = Bad_Handle); -- collected slot is the next generation

      Jobs.Wait (State, First, Code, S);
      pragma Assert (S = Success and Code = 42);
      pragma Assert (Jobs.Reserved_Pages (State) = 4);

      --  Collect the remaining admitted job, then raise the budget so the
      --  large job fits; admission, cancellation and stale ids repeat.
      Jobs.Fail (State, Third, S);
      pragma Assert (S = Success and Jobs.Reserved_Pages (State) = 0);
      Jobs.Wait (State, Third, Code, S);
      pragma Assert (S = Success and Code = 127);
      Jobs.Set_Page_Limit (State, 104);
      Jobs.Admit (State, Program, Program_Length, Pages, Huge, S);
      pragma Assert (S = Success and Program (1 .. Program_Length) = "/bin/huge");
      pragma Assert (Pages = 100 and Huge /= First and Huge /= Second and Huge /= Third);
      pragma Assert (Jobs.Reserved_Pages (State) = 100);
      Jobs.Cancel (State, Huge, S);
      pragma Assert (S = Success and Jobs.Reserved_Pages (State) = 0);
      Jobs.Cancel (State, Huge, S);
      pragma Assert (S = Bad_Handle); -- cancelled slot invalidates the id
      Jobs.Wait (State, Huge, Code, S);
      pragma Assert (S = Bad_Handle);

      --  A stale id from the first generation must not resolve.
      Jobs.Submit (State, "/bin/next", 0, Jobs.System, 1000, 1, First, S);
      pragma Assert (S = Success and First /= Third);
      Jobs.Fail (State, First, S);
      pragma Assert (S = Success);
      Jobs.Wait (State, First, Code, S);
      pragma Assert (S = Success and Code = 127);
      --  The re-submitted job was failed and collected; all slots are free.
      pragma Assert (Jobs.Count (State, Jobs.Held) = 0);
      pragma Assert (Jobs.Count (State, Jobs.Empty) = Jobs.Max_Jobs);
      Ada.Text_IO.Put_Line
       ("PASS job submit/admit priority and budget, bind, complete, cancel, stale id");
   end Run;
end Test_Jobs;
