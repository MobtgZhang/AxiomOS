package AxiomOS.Boot.Menu with Preelaborate is
   type Selection is (Normal_Boot, Diagnostics, Firmware_Return);
   type Action is (Move_Up, Move_Down, Confirm_Choice, Select_Normal,
                   Select_Diagnostics, Select_Firmware, No_Action);
   procedure Update (Choice : in out Selection; Input : Action;
                     Confirmed : out Boolean);
end AxiomOS.Boot.Menu;
