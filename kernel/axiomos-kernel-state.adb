package body AxiomOS.Kernel.State is
   procedure Initialize is
   begin
      -- Freestanding entry deliberately has no GNAT binder/adainit. All mutable
      -- kernel state is initialized explicitly before it becomes accessible.
      Handles := (others => <>);
      CPUs := (others => <>);
      Devices := (others => <>);
      Jobs.Initialize (Job_Table);
   end Initialize;
end AxiomOS.Kernel.State;
