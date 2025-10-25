{
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.modules.homeManager.base;
in
{
  options.modules.homeManager.base = {
    enable =
      mkEnableOption "Base user account and shell configuration"
      // {
        default = true;
      };
  };

  config = mkIf cfg.enable {
    nix.settings.trusted-users = [ "zekurio" ];

    environment.shells = with pkgs; [ fish bashInteractive ];
    environment.variables.EDITOR = "vim";

    programs.fish.enable = true;
    programs.nix-ld.enable = true;

    users = {
      users = {
        zekurio = {
          shell = pkgs.fish;
          uid = 1000;
          isNormalUser = true;
          hashedPassword = "$y$j9T$F7RSP23wOrzzmEJcTxY98.$i58fRl1nIbPjOZ4jBxLu/FWJb/i/DEytiWVtMxcd5G8";
          extraGroups = [
            "wheel"
            "users"
            "video"
            "podman"
            "input"
          ];
          group = "zekurio";
          openssh = {
            authorizedKeys.keys = [
              "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOCcQoZiY9wkJ+U93isE8B3CKLmzL7TPzVh3ugE1WPJq"
            ];
          };
        };
      };
      groups = {
        zekurio = {
          gid = 1000;
        };
      };
    };

    home-manager.users.zekurio = { pkgs, ... }: {
      home.username = "zekurio";
      home.homeDirectory = "/home/zekurio";
      home.stateVersion = "25.05";
      home.enableNixpkgsReleaseCheck = false;

      home.packages = with pkgs; [
        # CLI utilities
        bat
        btop
        eza
        fastfetch
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
          set -gx LD_LIBRARY_PATH (printf "%s" ${lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib pkgs.zlib pkgs.glib ]}):$LD_LIBRARY_PATH
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
        extraOptions = [ "--group-directories-first" "--icons=auto" ];
      };
    };
  };
}
