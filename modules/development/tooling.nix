{ lib, config, pkgs, ... }:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.modules.development.tooling;
in
{
  options.modules.development.tooling = {
    enable =
      mkEnableOption "System-wide development tooling"
      // {
        default = false;
      };
  };

  config = mkIf cfg.enable {
    environment.systemPackages =
      (with pkgs; [
        nodejs_22
        pnpm

        # Go
        go
        golangci-lint

        # Rust
        rustup

        # Build tools
        pkg-config
        cmake
        gnumake
        gcc
        clang

        # Python toolchain loader
        uv

        # Github CLI
        gh
      ])
      ++ (with pkgs.unstable; [
        bun
        codex
        opencode
      ]);
  };
}
