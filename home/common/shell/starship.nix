{
  programs.starship = {
    enable = true;
    enableNushellIntegration = true;

    settings = {
      scan_timeout = 10;
      add_newline = true;
      line_break.disabled = true;
      format = "$directory$git_branch$git_metrics$git_commit$git_state$git_status$all";
      character = {
        success_symbol = "[ ](bold #89b4fa)[ ➜](bold green)";
        error_symbol = "[ ](bold #89b4fa)[ ➜](bold red)";
        vimcmd_symbol = "[ ](bold #89b4fa)[ ➜](bold green)";
      };

      directory = {
        format = "[ ](bold #89b4fa)[ $path ]($style)";
        style = "bold #b4befe";
      };

      git_commit.tag_symbol = " tag ";
      git_branch = {
        style = "purple";
        symbol = "";
      };
      git_metrics = {
        added_style = "bold yellow";
        deleted_style = "bold red";
        disabled = false;
      };

      directory.substitutions = {
        "~" = "󰋞";
        "Documents" = " ";
        "Downloads" = " ";
        "Music" = " ";
        "Pictures" = " ";
      };

      aws.symbol = "aws ";
      bun.symbol = "bun ";
      c.symbol = "C ";
      cobol.symbol = "cobol ";
      conda.symbol = "conda ";
      crystal.symbol = "cr ";
      cmake.symbol = "cmake ";
      daml.symbol = "daml ";
      dart.symbol = "dart ";
      deno.symbol = "deno ";
      dotnet.symbol = ".NET ";
      directory.read_only = " ro";
      docker_context.symbol = "docker ";
      elixir.symbol = "exs ";
      elm.symbol = "elm ";
      golang.symbol = "go ";
      guix_shell.symbol = "guix ";
      hg_branch.symbol = "hg ";
      java.symbol = "java ";
      julia.symbol = "jl ";
      kotlin.symbol = "kt ";
      lua.symbol = "lua ";
      memory_usage.symbol = "memory ";
      meson.symbol = "meson ";
      nim.symbol = "nim ";
      nix_shell.symbol = "nix ";
      ocaml.symbol = "ml ";
      opa.symbol = "opa ";
      nodejs.symbol = "nodejs ";
      package.symbol = "pkg ";
      perl.symbol = "pl ";
      php.symbol = "php ";
      pulumi.symbol = "pulumi ";
      purescript.symbol = "purs ";
      python.symbol = "py ";
      raku.symbol = "raku ";
      ruby.symbol = "rb ";
      rust.symbol = "rs ";
      scala.symbol = "scala ";
      spack.symbol = "spack ";
      sudo.symbol = "sudo ";
      swift.symbol = "swift ";
      terraform.symbol = "terraform ";
      zig.symbol = "zig ";
    };
  };
}
