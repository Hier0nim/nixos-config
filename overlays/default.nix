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

  pythonDistutils = final: prev: {
    pythonPackagesExtensions = (prev.pythonPackagesExtensions or [ ]) ++ [
      (_pythonFinal: pythonPrev: {
        distutils = pythonPrev.distutils.overrideAttrs (old: {
          # Disable tests that fail with "RuntimeError: can't start new thread" in
          # constrained build environments (e.g. i686 cross-compilation under QEMU).
          # These are thread-spawning concurrency tests, not actual code bugs.
          disabledTests = (old.disabledTests or [ ]) ++ [
            "test_concurrent_safe"
            "TestParallelBuildExt"
          ];
        });
      })
    ];
  };
}
