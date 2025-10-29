{ lib
, config
, pkgsUnstable
, ...
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
    home-manager.users.zekurio = { pkgs, ... }:
      let
        jsDevShell =
          pkgs.writeShellApplication {
            name = "js-devshell";
            runtimeInputs = [
              pkgs.coreutils
              pkgs.nodejs_22
              pkgs.pnpm
              pkgsUnstable.bun
            ];
            text = ''
              set -euo pipefail

              if [ -z "''${XDG_DATA_HOME-}" ]; then
                export XDG_DATA_HOME="$HOME/.local/share"
              fi

              export NODE_ENV=development
              export NPM_CONFIG_PREFIX="$XDG_DATA_HOME/npm"
              export PNPM_HOME="$XDG_DATA_HOME/pnpm"
              export COREPACK_HOME="$XDG_DATA_HOME/corepack"
              export BUN_INSTALL="$HOME/.bun"

              mkdir -p \
                "$NPM_CONFIG_PREFIX/bin" \
                "$PNPM_HOME" \
                "$COREPACK_HOME" \
                "$BUN_INSTALL/bin"

              dev_path="${pkgs.nodejs_22}/bin:${pkgs.pnpm}/bin:${pkgsUnstable.bun}/bin"
              export PATH="$NPM_CONFIG_PREFIX/bin:$PNPM_HOME:$BUN_INSTALL/bin:$PWD/node_modules/.bin:$dev_path:$PATH"

              shell="''${SHELL:-${pkgs.fish}/bin/fish}"
              exec "$shell" -i
            '';
          };
      in
      {
        home.packages =
          [
            jsDevShell

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
