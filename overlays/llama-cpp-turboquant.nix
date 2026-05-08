final: prev: {
  llama-cpp-turboquant =
    (prev.llama-cpp.override {
      cudaSupport = true;
    }).overrideAttrs
      (old: {
        pname = "llama-cpp-turboquant";
        version = "6981";

        src = prev.fetchFromGitHub {
          owner = "TheTom";
          repo = "llama-cpp-turboquant";
          rev = "69d8e4be47243e83b3d0d71e932bc7aa61c644dc";
          hash = "sha256-JuyuYmewKWwYbNjBVcIB1mmgEMHibAm+tHzU+8R9pFw=";
          leaveDotGit = true;
          postFetch = ''
            git -C "$out" rev-parse --short HEAD > $out/COMMIT
            find "$out" -name .git -print0 | xargs -0 rm -rf
          '';
        };

        cmakeFlags = old.cmakeFlags ++ [
          "-DCMAKE_CUDA_ARCHITECTURES=61"
        ];
      });
}
