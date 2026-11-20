with System.Storage_Elements;
with Interfaces;
with Sysapi;
package body Memory_Probe is
   use type Sysapi.Word;
   procedure Main is
      Page : Interfaces.Unsigned_8 with Import, Volatile,
        Address => System.Storage_Elements.To_Address (16#10_0000_0000#);
      R : Sysapi.Word;
   begin
      R := Sysapi.Call (7, 16#10_0000_0000#, 4096, 3);
      if R = 16#10_0000_0000# then
         Page := 42;
         R := Sysapi.Call (13, 16#10_0000_0000#, 4096, 1);
         if R = 0 then Page := 43; end if; -- Must fault on a read-only PTE.
      end if;
      R := Sysapi.Call (0, 99, 0, 0);
      loop null; end loop;
   end Main;
end Memory_Probe;
