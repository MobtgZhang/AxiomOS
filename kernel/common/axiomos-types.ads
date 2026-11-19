with Interfaces;
package AxiomOS.Types with Pure is
   subtype U8 is Interfaces.Unsigned_8;
   subtype U16 is Interfaces.Unsigned_16;
   subtype U32 is Interfaces.Unsigned_32;
   subtype U64 is Interfaces.Unsigned_64;
   subtype I64 is Interfaces.Integer_64;
   use type Interfaces.Unsigned_64;
   type Physical_Address is new U64;
   type Virtual_Address is new U64;
   type Device_Address is new U64;
   type Bytes is array (Natural range <>) of U8;
   type Status is (Success, Invalid_Argument, Out_Of_Memory, Not_Found,
                   Already_Exists, Permission_Denied, Busy, Would_Block,
                   No_Space, Bad_Handle, Unsupported, IO_Error, Corrupt,
                   Timed_Out);
   Page_Size : constant U64 := 4096;
   function Fits (Base, Length : U64) return Boolean is
     (Length > 0 and then Base <= U64'Last - (Length - 1));
   function Aligned (Value, Alignment : U64) return Boolean is
     (Alignment /= 0 and then Value mod Alignment = 0);
   function Power_Of_Two (Value : U64) return Boolean is
     (Value /= 0 and then (Value and (Value - 1)) = 0);
end AxiomOS.Types;
