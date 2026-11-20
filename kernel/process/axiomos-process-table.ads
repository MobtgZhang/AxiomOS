with AxiomOS.VFS;
package AxiomOS.Process.Table with Preelaborate is
   procedure Initialize (State : in out Manager);
   function Resolve (State : Manager; Id : PID) return Natural;
   procedure Create (State : in out Manager; Parent : PID; Identity : Credentials;
                     Id : out PID; Result : out Status);
   procedure Make_Ready (State : in out Manager; Id : PID; Entry_Point,
                         Stack_Top : U64; Result : out Status);
   procedure Start (State : in out Manager; Id : PID; Result : out Status);
   procedure Exit_Process (State : in out Manager; Id : PID; Files : in out VFS.File_System; Code : U32;
                           Result : out Status);
   procedure Wait (State : in out Manager; Parent, Child : PID;
                   Code : out U32; Result : out Status);
end AxiomOS.Process.Table;
