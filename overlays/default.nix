_: {
  recyclarr = final: prev: {
    recyclarr = prev.recyclarr.overrideAttrs (old: {
      # Build only the CLI project instead of the whole solution (.slnx).
      # The .slnx includes test projects, and `dotnet publish` on a solution tries
      # to publish ALL projects to the same output directory, causing:
      #   - MSB3021: Access denied on CodeCoverage DLLs (test projects)
      #   - MSB3026: File locking on Recyclarr.Core.dll (concurrent writes)
      projectFile = "src/Recyclarr.Cli/Recyclarr.Cli.csproj";
    });
  };
}
