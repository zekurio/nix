{
  pkgs,
  lib,
  config,
  ...
}:
let
  use1Password = config.networking.hostName != "adam";
  onePassPath = "~/.1password/agent.sock";
in
{
  imports = [
    ./desktop.nix
  ];
  # System-level user configuration
  nix.settings.trusted-users = [ "zekurio" ];

  programs.vim = {
    enable = true;
    defaultEditor = true;
  };

  programs.zsh.enable = true;

  users = {
    users.zekurio = {
      shell = pkgs.zsh;
      uid = 1000;
      isNormalUser = true;
      hashedPassword = "$y$j9T$F7RSP23wOrzzmEJcTxY98.$i58fRl1nIbPjOZ4jBxLu/FWJb/i/DEytiWVtMxcd5G8";
      extraGroups = [
        "wheel"
        "users"
        "video"
        "podman"
        "input"
        "gamemode"
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

  # Home-manager configuration
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";

    users.zekurio = {
      home = {
        username = "zekurio";
        homeDirectory = "/home/zekurio";
        stateVersion = "25.05";

        packages = with pkgs; [
          age
          bat
          btop
          claude-code
          eza
          envsubst
          pfetch-rs
          git
          jq
          nil
          nixd
          opencode
          sops
          zellij
        ];
      };

      # Suppress version mismatch warning
      home.enableNixpkgsReleaseCheck = false;

      programs = {
        direnv = {
          enable = true;
          nix-direnv.enable = true;
        };

        eza = {
          enable = true;
          extraOptions = [
            "--group-directories-first"
            "--icons=auto"
          ];
        };

        zsh = {
          enable = true;
          autosuggestion.enable = true;
          syntaxHighlighting.enable = true;
          oh-my-zsh = {
            enable = true;
            plugins = [
              "git"
              "sudo"
              "direnv"
            ];
            theme = "robbyrussell";
          };
          initContent = ''
            # Disable greeting
            unsetopt BEEP
          '';
        };

        git = {
          enable = true;
          signing = lib.mkIf (!use1Password) {
            key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOCcQoZiY9wkJ+U93isE8B3CKLmzL7TPzVh3ugE1WPJq";
            signByDefault = true;
          };
          settings = lib.mkMerge [
            {
              user = {
                name = "Michael Schwieger";
                email = "git@zekurio.xyz";
              };
              init.defaultBranch = "main";
              pull.rebase = true;
              rebase.autoStash = true;
              gpg.format = "ssh";
            }
            (lib.mkIf use1Password {
              "gpg \"ssh\"".program = "${lib.getExe' pkgs._1password-gui "op-ssh-sign"}";
              commit.gpgsign = true;
              user.signingKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOCcQoZiY9wkJ+U93isE8B3CKLmzL7TPzVh3ugE1WPJq";
            })
          ];
        };

        ssh = {
          enable = true;
          enableDefaultConfig = false;
          extraConfig = lib.mkIf use1Password ''
            Host *
                IdentityAgent ${onePassPath}
          '';
          matchBlocks."*".compression = true;
        };
      };
    };
  };
}
