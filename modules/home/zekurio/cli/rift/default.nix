{
  flake.modules.homeManager.zekurio = {
    lib,
    pkgs,
    ...
  }:
    lib.mkIf pkgs.stdenv.hostPlatform.isDarwin (let
      rift = pkgs.callPackage ./_package.nix {};
    in {
      home.packages = [
        rift
      ];

      # Rift generates this per-workspace identity marker. Keep .rift.toml
      # visible because it contains optional, repository-owned postcreate hooks.
      programs.git.ignores = [".rift"];

      # Upstream only emits shell integration for Bash, Zsh, and Nushell.
      programs.fish.functions.rift = {
        description = "Manage copy-on-write workspaces";
        body = ''
          set -l subcommand
          if test (count $argv) -gt 0
            set subcommand $argv[1]
          end

          switch $subcommand
            case init create remove
              set -l rift_cwd (command rift --shell-cwd $argv)
              or return $status
              if test -n "$rift_cwd"
                builtin cd -- "$rift_cwd"
                or return $status
              end
            case '*'
              command rift $argv
          end
        '';
      };

      programs.nushell.extraConfig = ''
        source ${
          pkgs.runCommand "rift-nushell-config.nu" {} ''
            ${lib.getExe rift} shell-init nushell > "$out"
          ''
        }
      '';
    });
}
