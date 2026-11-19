with AxiomOS.Types; use AxiomOS.Types;
with AxiomOS.Boot.Protocol;
package AxiomOS.Kernel.Users is
   procedure Run (Info : Boot.Protocol.Boot_Info; Result : out Status);
end AxiomOS.Kernel.Users;
