with AxiomOS.Types; use AxiomOS.Types;
package AxiomOS.Memory.Virtual with Preelaborate is
   User_Limit : constant U64 := 16#0000_7FFF_FFFF_FFFF#;
   type Permissions is record
      Readable : Boolean := True;
      Writable, Executable, User, Device : Boolean := False;
   end record;
   type Mapping is record
      Virtual_Base, Physical_Base, Length : U64 := 0;
      Access_Rights : Permissions;
      Active : Boolean := False;
   end record;
   type Mapping_Array is array (Positive range 1 .. 128) of Mapping;
   type Address_Space is record
      Entries : Mapping_Array;
   end record;
   procedure Map (Space : in out Address_Space; Virtual_Base, Physical_Base,
                  Length : U64; Rights : Permissions; Result : out Status);
   procedure Unmap (Space : in out Address_Space; Virtual_Base, Length : U64;
                    Result : out Status);
   function Check_User (Space : Address_Space; Address, Length : U64;
                        Write : Boolean := False) return Boolean;
   function Valid_Range (Base, Length : U64; User : Boolean) return Boolean;
end AxiomOS.Memory.Virtual;
