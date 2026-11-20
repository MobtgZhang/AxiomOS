with AxiomOS.Types; use AxiomOS.Types;
with AxiomOS.Memory.Physical;
with AxiomOS.Memory.Virtual;
package AxiomOS.Memory.Spaces is
   use type U64;
   -- The dynamic user arena is outside the kernel's physical identity window
   -- and is representable by every supported MMU (including Sv39).
   User_First : constant U64 := 16#10_0000_0000#;
   User_End : constant U64 := User_First + 256 * 1024 * 1024;
   Max_Allocation : constant U64 := 1024 * 1024;
   Max_Committed : constant U64 := 16 * 1024 * 1024;
   procedure Allocate (Pages : in out Physical.Allocator;
                       Space : in out Virtual.Address_Space; Root : U64;
                       Address, Length : U64; Rights : Virtual.Permissions;
                       Result : out Status);
   procedure Release (Pages : in out Physical.Allocator;
                      Space : in out Virtual.Address_Space; Root : U64;
                      Address, Length : U64; Result : out Status);
   procedure Protect (Pages : in out Physical.Allocator;
                      Space : in out Virtual.Address_Space; Root : U64;
                      Address, Length : U64; Rights : Virtual.Permissions;
                      Result : out Status);
end AxiomOS.Memory.Spaces;
