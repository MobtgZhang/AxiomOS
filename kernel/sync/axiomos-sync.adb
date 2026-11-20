package body AxiomOS.Sync is
   use type U32, U64;

   function Slot (Word : not null access constant U32) return U64 is
      pragma Warnings (Off, Word);
   begin
      return Number (Word'Address);
   end Slot;

   function Load (Address : U64) return U32 is
   begin
      --  Compare_Exchange with any expectation returns the current word
      --  atomically; the store side never fires.
      return Compare_Exchange (Address, 0, 0);
   end Load;

   procedure Initialize (Lock : out Spinlock) is
   begin
      Lock.Ticket := 0;
      Lock.Grant := 0;
   end Initialize;

   procedure Acquire (Lock : in out Spinlock) is
      Mine : constant U32 := Fetch_Add (Number (Lock.Ticket'Address), 1);
   begin
      while Load (Number (Lock.Grant'Address)) /= Mine loop
         Pause;
      end loop;
   end Acquire;

   procedure Release (Lock : in out Spinlock) is
      Current : constant U32 := Load (Number (Lock.Grant'Address));
      Unused : U32;
      pragma Unreferenced (Unused);
   begin
      Unused := Compare_Exchange (Number (Lock.Grant'Address), Current, Current + 1);
   end Release;

   procedure Acquire (Lock : in out Mutex; Owner : U64; Result : out Status) is
   begin
      if Load (Number (Lock.State'Address)) /= 0 and then Lock.Owner = Owner then
         Result := Invalid_Argument;
         return;
      end if;
      while Compare_Exchange (Number (Lock.State'Address), 0, 1) /= 0 loop
         Pause;
      end loop;
      Lock.Owner := Owner;
      Result := Success;
   end Acquire;

   function Try_Acquire (Lock : in out Mutex; Owner : U64) return Status is
   begin
      if Load (Number (Lock.State'Address)) /= 0 and then Lock.Owner = Owner then
         return Invalid_Argument;
      end if;
      if Compare_Exchange (Number (Lock.State'Address), 0, 1) /= 0 then
         return Would_Block;
      end if;
      Lock.Owner := Owner;
      return Success;
   end Try_Acquire;

   procedure Release (Lock : in out Mutex; Owner : U64; Result : out Status) is
      Unused : U32;
      pragma Unreferenced (Unused);
   begin
      Result := Permission_Denied;
      if Lock.Owner /= Owner or else Load (Number (Lock.State'Address)) = 0 then
         return;
      end if;
      Lock.Owner := No_Owner;
      Unused := Compare_Exchange (Number (Lock.State'Address), 1, 0);
      Result := Success;
   end Release;

   procedure Initialize (Sema : out Semaphore; Initial, Maximum : U32) is
      Clamped : constant U32 := (if Initial > Maximum then Maximum else Initial);
      Unused : U32;
      pragma Unreferenced (Unused);
   begin
      Sema.Maximum := Maximum;
      --  The count word must start at zero (fresh or drained object);
      --  publishing through the atomic interface keeps the backing word and
      --  any injected substitute consistent.
      Unused := Compare_Exchange (Number (Sema.Count'Address), 0, Clamped);
   end Initialize;

   procedure Up (Sema : in out Semaphore; Result : out Status) is
      Current, Unused : U32;
      pragma Unreferenced (Unused);
   begin
      loop
         Current := Load (Number (Sema.Count'Address));
         if Current = Sema.Maximum then
            Result := No_Space;
            return;
         end if;
         Unused := Compare_Exchange (Number (Sema.Count'Address), Current, Current + 1);
         if Unused = Current then
            Result := Success;
            return;
         end if;
         Pause;
      end loop;
   end Up;

   function Try_Down (Sema : in out Semaphore) return Status is
      Current, Unused : U32;
   begin
      loop
         Current := Load (Number (Sema.Count'Address));
         if Current = 0 then
            return Would_Block;
         end if;
         Unused := Compare_Exchange (Number (Sema.Count'Address), Current, Current - 1);
         if Unused = Current then
            return Success;
         end if;
         Pause;
      end loop;
   end Try_Down;

   procedure Down (Sema : in out Semaphore) is
   begin
      while Try_Down (Sema) = Would_Block loop
         Pause;
      end loop;
   end Down;
end AxiomOS.Sync;
