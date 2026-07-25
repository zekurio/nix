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

      # Upstream emits shell integration for Bash, Zsh, and Nushell.
      programs.zsh.initContent = ''
        source ${
          pkgs.runCommand "rift-zsh-init.zsh" {} ''
            ${lib.getExe rift} shell-init zsh > "$out"
          ''
        }
      '';
    });
}
