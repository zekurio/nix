{
  lib,
  config,
  pkgsUnstable,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.modules.homeManager.dev;
in
{
  options.modules.homeManager.dev = {
    enable =
      mkEnableOption "Development tools and languages"
      // {
        default = false;
      };
  };

  config = mkIf cfg.enable {
    home-manager.users.zekurio = { pkgs, ... }: {
      home.packages = [
        # Node.js ecosystem
        pkgs.nodejs_22
        pkgs.pnpm
        pkgsUnstable.bun

        # Go
        pkgs.go
        pkgs.golangci-lint

        # Rust
        pkgs.rustup

        # Build tools
        pkgs.pkg-config
        pkgs.cmake
        pkgs.gnumake

        # Python, yuck
        pkgs.uv

        # Github CLI
        pkgs.gh

        # AI agents
        pkgsUnstable.codex
        pkgsUnstable.opencode
      ];
    };
  };
}
