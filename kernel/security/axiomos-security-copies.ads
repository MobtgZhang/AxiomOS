with System;
with AxiomOS.Memory.Virtual;
with AxiomOS.Types; use AxiomOS.Types;
generic
   with procedure Move (Target, Source, Length : U64);
   with function Number (Address : System.Address) return U64;
package AxiomOS.Security.Copies is
   procedure Read (Space : Memory.Virtual.Address_Space; Address : U64;
                   Buffer : out Bytes; Result : out Status);
   procedure Write (Space : Memory.Virtual.Address_Space; Address : U64;
                    Buffer : Bytes; Result : out Status);
end AxiomOS.Security.Copies;
