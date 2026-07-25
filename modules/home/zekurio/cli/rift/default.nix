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

      programs.nushell.extraConfig = ''
        source ${
          pkgs.runCommand "rift-nushell-config.nu" {} ''
            ${lib.getExe rift} shell-init nushell > "$out"
          ''
        }
      '';
    });
}
