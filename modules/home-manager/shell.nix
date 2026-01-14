{
  pkgs,
  lib,
  config,
  ...
}: let
  cfg = config.modules.hm.shell;
  isDesktop = config.modules.hm.desktop.enable;
  onePassPath = "~/.1password/agent.sock";
  signingKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOCcQoZiY9wkJ+U93isE8B3CKLmzL7TPzVh3ugE1WPJq";
in {
  options.modules.hm.shell = {
    enable =
      lib.mkEnableOption "shell configuration"
      // {
        default = true;
      };
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.zekurio = {
      home.packages = with pkgs; [
        age
        bat
        btop
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
          signing = {
            key = signingKey;
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
            # Desktop: use 1Password's op-ssh-sign
            (lib.mkIf isDesktop {
              "gpg \"ssh\"".program = "${lib.getExe' pkgs._1password-gui "op-ssh-sign"}";
            })
            # Non-desktop: use ssh-keygen which reads from SSH_AUTH_SOCK (forwarded agent)
            (lib.mkIf (!isDesktop) {
              "gpg \"ssh\"".program = "/run/current-system/sw/bin/ssh-keygen";
            })
          ];
        };

        ssh = {
          enable = true;
          enableDefaultConfig = false;
          extraConfig = lib.mkIf isDesktop ''
            Host *
                IdentityAgent ${onePassPath}
          '';
          matchBlocks."*".compression = true;
        };
      };
    };
  };
}
