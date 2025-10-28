{
  lib,
  config,
  ...
}: let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.modules.homeManager.base;
in {
  options.modules.homeManager.base = {
    enable =
      mkEnableOption "Base user account and shell configuration"
      // {
        default = true;
      };
  };

  config = mkIf cfg.enable {
    home-manager.users.zekurio = {pkgs, ...}: {
      home.username = "zekurio";
      home.homeDirectory = "/home/zekurio";
      home.stateVersion = "25.05";
      home.enableNixpkgsReleaseCheck = false;

      home.packages = with pkgs; [
        # CLI utilities
        bat
        btop
        eza
        pfetch
        jq
        envsubst
        zellij
        # Version control
        git
        # Nix tools
        nil
        nixd
        sops
        age
      ];

      programs.fish = {
        enable = true;
        interactiveShellInit = ''
          set -g fish_greeting
          fish_add_path "/home/zekurio/.bun/bin"
          set -gx LD_LIBRARY_PATH (printf "%s" ${lib.makeLibraryPath [pkgs.stdenv.cc.cc.lib pkgs.zlib pkgs.glib]}):$LD_LIBRARY_PATH
        '';
        plugins = [
          {
            name = "pure";
            src = pkgs.fishPlugins.pure.src;
          }
        ];
      };

      programs.eza = {
        enable = true;
        extraOptions = ["--group-directories-first" "--icons=auto"];
      };
    };
  };
}
