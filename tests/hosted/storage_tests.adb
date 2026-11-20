with Ada.Text_IO;
with Ada.Command_Line;
with Ada.Streams.Stream_IO;
with Ada.Streams;
with AxiomOS.Types; use AxiomOS.Types;
with AxiomOS.Storage; use AxiomOS.Storage;
with AxiomOS.Storage.Volumes;
with AxiomOS.VFS.Mounts;
with AxiomOS.IO.Handles;
with AxiomOS.IO.Streams;
with AxiomOS.VFS.Tmpfs;
procedure Storage_Tests is
   package SIO renames Ada.Streams.Stream_IO;
   use type Ada.Streams.Stream_Element_Offset, SIO.Count, U8, U64;
   type U64_Array is array (Natural range <>) of U64;
   Disk_File : SIO.File_Type;
   V : Volume;
   Item : File_Object;
   FS : AxiomOS.VFS.File_System;
   Handles : AxiomOS.IO.Handle_Table;
   Handle : AxiomOS.IO.Handle;
   S : Status;
   Buffer : Bytes (0 .. 8191);
   Count : Natural;
   Node : AxiomOS.VFS.Node_Id;
   Position : U64;
   Corrupt_At : U64 := U64'Last;
   Patch_At : U64 := U64'Last;
   Patch : Bytes (0 .. 3) := (others => 0);
   Patch_Length : Natural := 0;
   procedure Read_Disk (Offset : U64; Buffer : out Bytes; Result : out Status) is
      Data : Ada.Streams.Stream_Element_Array (1 .. Ada.Streams.Stream_Element_Offset (Buffer'Length));
      Last : Ada.Streams.Stream_Element_Offset;
   begin
      SIO.Set_Index (Disk_File, SIO.Count (Offset) + 1);
      SIO.Read (Disk_File, Data, Last);
      if Last /= Data'Last then Result := IO_Error; return; end if;
      for I in Buffer'Range loop Buffer (I) := U8 (Data (Data'First + Ada.Streams.Stream_Element_Offset (I - Buffer'First))); end loop;
      if Corrupt_At >= Offset and then Corrupt_At - Offset < U64 (Buffer'Length) then
         Buffer (Buffer'First + Natural (Corrupt_At - Offset)) := Buffer (Buffer'First + Natural (Corrupt_At - Offset)) xor 16#FF#;
      end if;
      for I in 0 .. Integer (Patch_Length) - 1 loop
         if Patch_At + U64 (I) >= Offset and then Patch_At + U64 (I) - Offset < U64 (Buffer'Length) then
            Buffer (Buffer'First + Natural (Patch_At + U64 (I) - Offset)) := Patch (I);
         end if;
      end loop;
      Result := Success;
   end Read_Disk;
   Device_View : Device;
   procedure Require (OK : Boolean; Detail : String) is
   begin
      if not OK then
         Ada.Text_IO.Put_Line ("FAIL " & Detail & " status=" & S'Image);
         raise Program_Error with Detail;
      end if;
   end Require;
   procedure Check (Path, Expected : String) is
   begin
      Volumes.Lookup (V, Path, Item, S); Require (S = Success, "lookup " & Path);
      Volumes.Read_File (V, Item, 0, Buffer, Count, S);
      Require (S = Success and Count = Expected'Length, "read " & Path);
      for I in Expected'Range loop Require (Buffer (I - Expected'First) = Character'Pos (Expected (I)), "content " & Path); end loop;
   end Check;
begin
   SIO.Open (Disk_File, SIO.In_File, Ada.Command_Line.Argument (1));
   Device_View := (Read_Disk'Unrestricted_Access, 0, U64 (SIO.Size (Disk_File)));
   Volumes.Mount (Device_View, V, S); Require (S = Success, "mount");
   Check ("/hello.txt", "hello from a real filesystem" & ASCII.LF);
   Check ("/long-file-name.txt", "long filename contents" & ASCII.LF);
   Check ("/empty", "");
   if V.Kind /= NTFS_Volume then Check ("/tree/deep.txt", "nested directory" & ASCII.LF);
   else Check ("/entry-079.txt", "hello from a real filesystem" & ASCII.LF); end if;
   Volumes.Lookup (V, "/large.bin", Item, S); Require (S = Success and Item.Length = 400000, "large stat");
   for Offset of U64_Array'(0, 4091, 65000, 270000, 391808) loop
      Volumes.Read_File (V, Item, Offset, Buffer, Count, S);
      Require (S = Success and Count = Buffer'Length, "large offset");
      for I in Buffer'Range loop
         Require (Buffer (I) = U8 (((Offset + U64 (I)) * 17 + (Offset + U64 (I)) / 256) mod 251), "large content");
      end loop;
   end loop;
   if V.Kind in FAT16 | FAT32 then
      Patch_Length := (if V.Kind = FAT16 then 2 else 4);
      Patch_At := V.FAT_Start + Item.Id * U64 (Patch_Length);
      for I in 0 .. Patch_Length - 1 loop Patch (I) := U8 ((Item.Id / (256 ** I)) mod 256); end loop;
      Volumes.Read_File (V, Item, 0, Buffer, Count, S); Require (S = Corrupt, "cyclic FAT chain");
      Patch_Length := 0; Patch_At := U64'Last;
   end if;
   Volumes.Read_File (V, Item, 400000, Buffer, Count, S); Require (S = Success and Count = 0, "EOF");
   Volumes.Lookup (V, "/sparse.bin", Item, S); Require (S = Success, "sparse stat");
   for Offset of U64_Array'(0, 4090, 40000, 960000) loop
      Volumes.Read_File (V, Item, Offset, Buffer, Count, S); Require (S = Success and Count = Buffer'Length, "sparse read");
      for I in Buffer'Range loop
         declare Block : constant U64 := (Offset + U64 (I)) / 4096;
         begin Require (Buffer (I) = (if Block mod 2 = 0 then U8 (Block mod 251 + 1) else 0), "sparse content"); end;
      end loop;
   end loop;
   Volumes.Lookup (V, "/missing", Item, S); Require (S = Not_Found, "missing");
   Volumes.Lookup (V, "/../hello.txt", Item, S); Require (S = Permission_Denied, "path escape");
   AxiomOS.VFS.Mounts.Mount_Root (FS, Device_View, S); Require (S = Success, "VFS mount");
   AxiomOS.IO.Handles.Open (Handles, FS, "/large.bin", (True, False), Handle, S); Require (S = Success, "VFS open");
   AxiomOS.IO.Streams.Read (Handles, FS, Handle, Buffer, Count, S); Require (S = Success and Count = Buffer'Length, "VFS read");
   AxiomOS.IO.Streams.Seek (Handles, FS, Handle, 270000, AxiomOS.IO.Streams.Beginning, Position, S);
   Require (S = Success and Position = 270000, "VFS seek");
   AxiomOS.IO.Streams.Read (Handles, FS, Handle, Buffer, Count, S);
   Require (S = Success and Count = Buffer'Length and Buffer (0) = U8 ((270000 * 17 + 270000 / 256) mod 251), "VFS seek content");
   AxiomOS.IO.Handles.Close (Handles, FS, Handle, S); Require (S = Success, "close disk");
   AxiomOS.IO.Handles.Open (Handles, FS, "/large.bin", (True, True), Handle, S); Require (S = Permission_Denied, "disk write protection");
   AxiomOS.VFS.Tmpfs.Create (FS, "/overlay", AxiomOS.VFS.Regular, Node, S);
   Require (S = Permission_Denied, "no implicit tmpfs overlay on disk");
   AxiomOS.VFS.Tmpfs.Initialize (FS);
   AxiomOS.VFS.Tmpfs.Create (FS, "/disk", AxiomOS.VFS.Directory, Node, S);
   Require (S = Success, "mount point");
   AxiomOS.VFS.Tmpfs.Create (FS, "/diskette", AxiomOS.VFS.Regular, Node, S);
   Require (S = Success, "sibling component");
   AxiomOS.VFS.Tmpfs.Create (FS, "/second", AxiomOS.VFS.Directory, Node, S);
   AxiomOS.VFS.Mounts.Mount_Disk (FS, "/disk", Device_View, S); Require (S = Success, "secondary mount");
   AxiomOS.VFS.Mounts.Mount_Disk (FS, "/second", Device_View, S); Require (S = Success, "second volume instance");
   AxiomOS.IO.Handles.Open (Handles, FS, "/disk/hello.txt", (True, False), Handle, S);
   Require (S = Success, "volume relative lookup");
   AxiomOS.VFS.Mounts.Unmount (FS, "/disk", S); Require (S = Busy, "mounted disk lease");
   AxiomOS.IO.Streams.Read (Handles, FS, Handle, Buffer, Count, S);
   Require (S = Success and Count = 29, "mounted disk read");
   AxiomOS.VFS.Mounts.Lookup (FS, "/diskette", Node, S); Require (S = Success, "component prefix matching");
   AxiomOS.IO.Handles.Close_All (Handles, FS);
   AxiomOS.VFS.Mounts.Unmount (FS, "/disk", S); Require (S = Success, "disk unmount");
   AxiomOS.VFS.Mounts.Lookup (FS, "/disk/hello.txt", Node, S); Require (S = Not_Found, "unmount cache invalidation");
   AxiomOS.IO.Handles.Open (Handles, FS, "/second/hello.txt", (True, False), Handle, S);
   Require (S = Success, "independent mount survives");
   AxiomOS.IO.Handles.Close_All (Handles, FS);
   AxiomOS.VFS.Mounts.Unmount (FS, "/second", S); Require (S = Success, "second unmount");
   AxiomOS.Storage.Read (Device_View, Device_View.Length - 1, Buffer, S); Require (S = Invalid_Argument, "device bounds");
   if V.Kind = EXT4 then
      Corrupt_At := 1024 + 104;
      Volumes.Mount (Device_View, V, S); Require (S = Corrupt, "EXT4 super checksum");
      Corrupt_At := U64'Last;
      Volumes.Mount (Device_View, V, S); Require (S = Success, "remount");
   elsif V.Kind = NTFS_Volume then
      Corrupt_At := V.MFT * V.Block_Size + 510;
      Volumes.Mount (Device_View, V, S); Require (S = Corrupt, "NTFS torn record");
      Corrupt_At := U64'Last;
   end if;
   Device_View.Length := 1024; Volumes.Mount (Device_View, V, S); Require (S /= Success, "truncated volume");
   Ada.Text_IO.Put_Line ("PASS real disk, directories, names, large offsets, EOF, VFS, readonly, truncation: " & Ada.Command_Line.Argument (1));
   SIO.Close (Disk_File);
end Storage_Tests;
