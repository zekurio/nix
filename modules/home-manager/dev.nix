{ lib
, config
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
        gccLibPath = lib.makeLibraryPath [ pkgs.stdenv.cc.cc ];
        sessionPath = [
          "$NPM_CONFIG_PREFIX/bin"
          "$PNPM_HOME"
          "$BUN_INSTALL/bin"
        ];
      in
      {
        home.sessionVariables = {
          XDG_DATA_HOME = lib.mkDefault "$HOME/.local/share";
          NPM_CONFIG_PREFIX = "$XDG_DATA_HOME/npm";
          PNPM_HOME = "$XDG_DATA_HOME/pnpm";
          COREPACK_HOME = "$XDG_DATA_HOME/corepack";
          BUN_INSTALL = "$HOME/.bun";
        };
        home.sessionVariablesExtra = ''
          if [ -z "''${LD_LIBRARY_PATH-}" ]; then
            export LD_LIBRARY_PATH="${gccLibPath}"
          else
            export LD_LIBRARY_PATH="${gccLibPath}:''${LD_LIBRARY_PATH}"
          fi
        '';
        home.activation.ensureJsDevEnv = {
          before = [ ];
          after = [ "writeBoundary" ];
          data = ''
            set -euo pipefail

            xdg_data_home="''${XDG_DATA_HOME:-$HOME/.local/share}"
            npm_prefix="''${NPM_CONFIG_PREFIX:-$xdg_data_home/npm}"
            pnpm_home="''${PNPM_HOME:-$xdg_data_home/pnpm}"
            corepack_home="''${COREPACK_HOME:-$xdg_data_home/corepack}"
            bun_install="''${BUN_INSTALL:-$HOME/.bun}"

            mkdir -p \
              "$npm_prefix/bin" \
              "$pnpm_home" \
              "$corepack_home" \
              "$bun_install/bin"
          '';
        };
        home.sessionPath = sessionPath;
      };
  };
}
