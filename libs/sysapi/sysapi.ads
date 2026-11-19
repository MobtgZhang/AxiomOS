with Interfaces;
package Sysapi with Preelaborate is
   subtype Word is Interfaces.Unsigned_64;
   -- ABI v1: nonnegative result, or -(Status'Pos + 1) on failure.
   function Call (Number, A0, A1, A2 : Word) return Word
     with Import, Convention => C, External_Name => "axiom_syscall";
end Sysapi;
