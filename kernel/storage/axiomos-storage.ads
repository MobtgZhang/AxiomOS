with AxiomOS.Types; use AxiomOS.Types;
package AxiomOS.Storage with Preelaborate is
   type Read_Operation is access procedure
     (Offset : U64; Buffer : out Bytes; Result : out Status);
   type Device is record
      Read : Read_Operation := null;
      Base, Length : U64 := 0;
   end record;
   type Format is (Unknown, FAT16, FAT32, NTFS_Volume, EXT2, EXT3, EXT4);
   type File_Object is record
      Id, Length : U64 := 0;
      Directory : Boolean := False;
   end record;
   -- Mount metadata is fixed-size; no allocator or host runtime is needed.
   type Volume is record
      Disk : Device;
      Kind : Format := Unknown;
      Root : File_Object;
      Block_Size, Blocks, Inodes, Per_Group, Inodes_Per_Group : U64 := 0;
      Inode_Size, Descriptor_Size, Descriptors, Features : U64 := 0;
      Metadata_Checksum : Boolean := False;
      Checksum_Seed : U32 := 0;
      FAT_Start, Data_Start, Root_Start, Root_Entries, Cluster_Count : U64 := 0;
      MFT, Record_Size, Index_Size : U64 := 0;
   end record;
   procedure Read (Disk : Device; Offset : U64; Buffer : out Bytes; Result : out Status);
end AxiomOS.Storage;
