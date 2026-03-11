{
  pkgs,
  lib,
  config,
  inputs,
  ...
}: let
  cfg = config.modules.users.zekurio;
in {
  options.modules.users.zekurio = {
    opencodeWeb.enable = lib.mkEnableOption "OpenCode web user service for zekurio";
  };

  config = {
    # System-level user configuration
    nix.settings.trusted-users = ["zekurio"];

    programs.vim = {
      enable = true;
      defaultEditor = true;
    };

    programs.zsh.enable = true;

    users = {
      defaultUserShell = pkgs.zsh;

      users.zekurio = {
        shell = pkgs.zsh;
        uid = 1000;
        isNormalUser = true;
        linger = cfg.opencodeWeb.enable;
        hashedPassword = "$y$j9T$F7RSP23wOrzzmEJcTxY98.$i58fRl1nIbPjOZ4jBxLu/FWJb/i/DEytiWVtMxcd5G8";
        extraGroups = [
          "wheel"
          "users"
          "video"
          "podman"
          "input"
        ];
        group = "zekurio";
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOXuY93/KsNdn9B9LW4JwPGpHa5d5W0XHYttP5wdHDb8 zekurio@termius"
        ];
      };

      groups.zekurio = {
        gid = 1000;
      };
    };

    # Home-manager base configuration
    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      backupFileExtension = "backup";
      extraSpecialArgs = {
        inherit inputs;
      };

      users.zekurio = {
        imports = [
          inputs.sops-nix.homeManagerModules.sops
          ../shell/hm
        ];

        modules.hm.shell.opencodeWeb.enable = cfg.opencodeWeb.enable;

        home = {
          username = "zekurio";
          homeDirectory = "/home/zekurio";
          stateVersion = "25.05";
          enableNixpkgsReleaseCheck = false;
        };
      };
    };
  };
}
