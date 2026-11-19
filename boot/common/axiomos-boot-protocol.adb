package body AxiomOS.Boot.Protocol is
   use type U32, U64;
   function Valid (Info : Boot_Info) return Boolean is
     (Info.Magic = Magic_Value and then Info.Version = ABI_Version and then
      Info.Structure_Size = 136 and then Info.Memory_Map /= 0 and then
      Info.Descriptor_Size >= 40 and then Info.Memory_Map_Size > 0 and then
      Info.Memory_Map_Size mod Info.Descriptor_Size = 0 and then
      Fits (Info.Memory_Map, Info.Memory_Map_Size) and then
      Fits (Info.Kernel_Base, Info.Kernel_Size) and then
      Fits (Info.Stack_Base, Info.Stack_Size));
end AxiomOS.Boot.Protocol;
