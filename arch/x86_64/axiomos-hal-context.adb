with Interfaces;
with AxiomOS.Raw;
package body AxiomOS.HAL.Context is
   use type U64;
   GDT : aliased Bytes (0 .. 55) with Alignment => 16;
   TSS : aliased Bytes (0 .. 103) with Alignment => 16;
   IDT : aliased Bytes (0 .. 4095) with Alignment => 16;
   GDT_Pointer, IDT_Pointer : aliased Bytes (0 .. 9);
   Syscall_Stub : aliased U8 with Import, External_Name => "axiom_syscall_stub";
   Fault_Stub : aliased U8 with Import, External_Name => "axiom_fault_stub";
   Page_Fault_Stub : aliased U8 with Import, External_Name => "axiom_page_fault_stub";
   procedure Load_Tables (GDT, IDT : U64)
     with Import, Convention => C, External_Name => "axiom_load_tables";
   procedure Initialize (Kernel_Stack : U64; Result : out Status) is
      Base : constant U64 := Raw.Number (GDT'Address);
      T : constant U64 := Raw.Number (TSS'Address);
      D : U64;
      procedure Gate (Vector : Natural; Handler : U64; Attributes : U8) is
         P : constant U64 := Raw.Number (IDT'Address) + U64 (Vector) * 16;
      begin
         Raw.Store16 (P, U16 (Handler and 16#FFFF#));
         Raw.Store16 (P + 2, 8);
         Raw.Store8 (P + 5, Attributes);
         Raw.Store16 (P + 6, U16 (Interfaces.Shift_Right (Handler, 16) and 16#FFFF#));
         Raw.Store32 (P + 8, U32 (Interfaces.Shift_Right (Handler, 32)));
      end Gate;
   begin
      Raw.Zero (Base, 56);
      Raw.Zero (T, 104);
      Raw.Zero (Raw.Number (IDT'Address), 4096);
      Raw.Store64 (Base + 8, 16#00AF9A000000FFFF#);
      Raw.Store64 (Base + 16, 16#00CF92000000FFFF#);
      Raw.Store64 (Base + 24, 16#00CFF2000000FFFF#);
      Raw.Store64 (Base + 32, 16#00AFFA000000FFFF#);
      D := 103 or Interfaces.Shift_Left (T and 16#FFFFFF#, 16) or
        16#0000890000000000# or Interfaces.Shift_Left (T and 16#FF000000#, 32);
      Raw.Store64 (Base + 40, D);
      Raw.Store64 (Base + 48, Interfaces.Shift_Right (T, 32));
      Raw.Store64 (T + 4, Kernel_Stack);
      Raw.Store16 (T + 102, 104);
      for I in 0 .. 255 loop Gate (I, Raw.Number (Fault_Stub'Address), 16#8E#); end loop;
      Gate (14, Raw.Number (Page_Fault_Stub'Address), 16#8E#);
      Gate (16#80#, Raw.Number (Syscall_Stub'Address), 16#EE#);
      Raw.Store16 (Raw.Number (GDT_Pointer'Address), 55);
      Raw.Store64 (Raw.Number (GDT_Pointer'Address) + 2, Base);
      Raw.Store16 (Raw.Number (IDT_Pointer'Address), 4095);
      Raw.Store64 (Raw.Number (IDT_Pointer'Address) + 2, Raw.Number (IDT'Address));
      Load_Tables (Raw.Number (GDT_Pointer'Address), Raw.Number (IDT_Pointer'Address));
      Result := Success;
   end Initialize;
end AxiomOS.HAL.Context;
