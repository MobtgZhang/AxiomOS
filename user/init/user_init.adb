with System.Storage_Elements;
with Sysapi;
package body User_Init is
   use Sysapi;
   use type Word;
   function Pointer (A : System.Address) return Word is
     (Word (System.Storage_Elements.To_Integer (A)));
   procedure Main is
      Message : aliased constant String := "AXIOM:USER:ADA:HELLO" & Character'Val (10);
      Path : aliased constant String := "/etc/motd";
      Buffer : aliased String (1 .. 64);
      Handle, Count, Ignore : Word;
      procedure Exit_With (Code : Word) with No_Return;
      procedure Exit_With (Code : Word) is
         R : Word;
      begin
         R := Call (0, Code, 0, 0);
         loop null; end loop;
      end Exit_With;
   begin
      Count := Call (2, 257, Pointer (Message'Address), Message'Length);
      if Count /= Message'Length then Exit_With (10); end if;
      -- A supervisor address must be rejected before copying any bytes.
      Count := Call (2, 257, 16#100000#, 16);
      if Count < 2 ** 63 then Exit_With (11); end if;
      Handle := Call (3, Pointer (Path'Address), Path'Length, 1);
      if Handle >= 2 ** 63 then Exit_With (12); end if;
      Count := Call (1, Handle, Pointer (Buffer'Address), Buffer'Length);
      if Count = 0 or else Count > Buffer'Length then Exit_With (13); end if;
      Ignore := Call (2, 257, Pointer (Buffer'Address), Count);
      Ignore := Call (4, Handle, 0, 0);
      Exit_With (0);
   end Main;
end User_Init;
