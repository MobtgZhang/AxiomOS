with System.Storage_Elements;
with Interfaces;
with Sysapi;
package body Isolation_Probe is
   procedure Main is
      Protected_Byte : Interfaces.Unsigned_8
        with Import, Volatile, Address => System.Storage_Elements.To_Address (16#100000#);
      Ignore : Sysapi.Word;
   begin
      -- This store must raise a hardware privilege fault. Reaching exit is a failure.
      Protected_Byte := 16#AA#;
      Ignore := Sysapi.Call (0, 99, 0, 0);
      loop null; end loop;
   end Main;
end Isolation_Probe;
