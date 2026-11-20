with System.Storage_Elements;
with Sysapi;
with Interfaces;
package body User_Init is
   use Sysapi;
   use type Word;
   use type Interfaces.Unsigned_8;
   function Pointer (A : System.Address) return Word is
     (Word (System.Storage_Elements.To_Integer (A)));
   procedure Main is
      Message : aliased constant String := "AXIOM:USER:ADA:HELLO" & Character'Val (10);
      Path : aliased constant String := "/etc/motd";
      Buffer : aliased String (1 .. 64) with Volatile;
      Handle, Count, Ignore : Word;
      Base : constant Word := 16#10_0000_0000#;
      type Data is array (Natural range 0 .. 8191) of Interfaces.Unsigned_8;
      Pages : Data with Import, Volatile,
        Address => System.Storage_Elements.To_Address (16#10_0000_0000#);
      Clock : Word;
      Data_Path : aliased constant String := "/tmp/user-data";
      Payload : aliased constant String := "Ada file I/O";
      Copy_Handle : Word;
      Passed : aliased constant String := "AXIOM:USER:MEMORY:PASS" & Character'Val (10);
      Files_Passed : aliased constant String := "AXIOM:USER:FILES:PASS" & Character'Val (10);
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
      Clock := Call (11, 0, 0, 0);
      if Call (7, Base, 4096, 3) /= Base or else
        Call (7, Base + 4096, 4096, 3) /= Base + 4096 then Exit_With (20); end if;
      for I in Pages'Range loop
         if Pages (I) /= 0 then Exit_With (21); end if;
      end loop;
      if Call (7, Base, 4096, 3) < 2 ** 63 or else
        Call (7, Base + 8192, 4096, 7) < 2 ** 63 or else
        Call (7, Base + 1, 4096, 3) < 2 ** 63 then Exit_With (22); end if;
      Handle := Call (3, Pointer (Path'Address), Path'Length, 1);
      Count := Call (1, Handle, Base + 4090, 64);
      if Count = 0 or else Count > 64 then Exit_With (23); end if;
      if Call (2, 257, Base + 4090, Count) /= Count then Exit_With (24); end if;
      -- Whole-range validation must reject this read before advancing the file.
      if Call (13, Base + 4096, 4096, 1) /= 0 then Exit_With (25); end if;
      if Call (1, Handle, Base + 4090, 64) < 2 ** 63 then Exit_With (26); end if;
      if Call (13, Base + 4096, 4096, 3) /= 0 then Exit_With (27); end if;
      Ignore := Call (4, Handle, 0, 0);
      Pages (0) := 99;
      if Call (8, Base, 4096, 0) /= 0 or else Call (8, Base, 4096, 0) < 2 ** 63 then Exit_With (28); end if;
      if Call (7, Base, 4096, 3) /= Base or else Pages (0) /= 0 then Exit_With (29); end if;
      if Call (8, Base, 4096, 0) /= 0 or else Call (8, Base + 4096, 4096, 0) /= 0 then Exit_With (30); end if;
      if Call (11, 0, 0, 0) < Clock then Exit_With (31); end if;
      Ignore := Call (2, 257, Pointer (Passed'Address), Passed'Length);
      Handle := Call (3, Pointer (Data_Path'Address), Data_Path'Length, 3);
      if Handle >= 2 ** 63 then Exit_With (40); end if;
      if Call (2, Handle, Pointer (Payload'Address), Payload'Length) /= Payload'Length or else
        Call (15, Handle, 0, 0) /= Payload'Length then Exit_With (41); end if;
      -- Signed -3 relative to EOF, followed by a read-only, independent cursor.
      if Call (14, Handle, Word'Last - 2, 2) /= Payload'Length - 3 then Exit_With (42); end if;
      Copy_Handle := Call (16, Handle, 1, 0);
      if Copy_Handle >= 2 ** 63 then Exit_With (43); end if;
      if Call (2, Copy_Handle, Pointer (Payload'Address), 1) < 2 ** 63 or else
        Call (16, Copy_Handle, 3, 0) < 2 ** 63 then Exit_With (44); end if;
      if Call (1, Copy_Handle, Pointer (Buffer'Address), 3) /= 3 then Exit_With (45); end if;
      for I in 1 .. 3 loop
         if Buffer (I) /= Payload (Payload'Length - 3 + I) then Exit_With (45); end if;
      end loop;
      if Call (14, Handle, 0, 1) /= Payload'Length - 3 then Exit_With (46); end if;
      if Call (4, Copy_Handle, 0, 0) /= 0 or else
        Call (15, Copy_Handle, 0, 0) < 2 ** 63 then Exit_With (47); end if;
      if Call (14, Handle, 0, 0) /= 0 or else
        Call (1, Handle, Pointer (Buffer'Address), Payload'Length) /= Payload'Length then Exit_With (48); end if;
      for I in Payload'Range loop
         if Buffer (I) /= Payload (I) then Exit_With (48); end if;
      end loop;
      Ignore := Call (2, 257, Pointer (Files_Passed'Address), Files_Passed'Length);
      -- Deliberately leave Handle open: Exit_Process must drop the mount lease.
      Exit_With (0);
   end Main;
end User_Init;
