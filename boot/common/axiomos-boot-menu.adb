package body AxiomOS.Boot.Menu is
   procedure Update (Choice : in out Selection; Input : Action;
                     Confirmed : out Boolean) is
   begin
      Confirmed := False;
      case Input is
         when Move_Up =>
            Choice := (if Choice = Selection'First then Selection'Last
                       else Selection'Pred (Choice));
         when Move_Down =>
            Choice := (if Choice = Selection'Last then Selection'First
                       else Selection'Succ (Choice));
         when Confirm_Choice => Confirmed := True;
         when Select_Normal => Choice := Normal_Boot; Confirmed := True;
         when Select_Diagnostics => Choice := Diagnostics; Confirmed := True;
         when Select_Firmware => Choice := Firmware_Return; Confirmed := True;
         when No_Action => null;
      end case;
   end Update;
end AxiomOS.Boot.Menu;
