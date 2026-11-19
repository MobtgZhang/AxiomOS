with AxiomOS.Types; use AxiomOS.Types;
with AxiomOS.Memory.Virtual;
package AxiomOS.Security.User_Memory with Preelaborate is
   -- The caller holds the address-space lock until the copy completes.
   procedure Translate (Space : Memory.Virtual.Address_Space; Address, Length : U64;
                         Write : Boolean; Physical : out U64; Result : out Status);
end AxiomOS.Security.User_Memory;
