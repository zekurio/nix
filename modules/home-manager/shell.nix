{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.modules.hm.shell;
  signingKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOCcQoZiY9wkJ+U93isE8B3CKLmzL7TPzVh3ugE1WPJq";
in
{
  options.modules.hm.shell = {
    enable = lib.mkEnableOption "shell configuration" // {
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
        sops
        uv
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
          settings = {
            user = {
              name = "Michael Schwieger";
              email = "git@zekurio.xyz";
            };
            init.defaultBranch = "main";
            pull.rebase = true;
            rebase.autoStash = true;
            gpg.format = "ssh";
            "gpg \"ssh\"".program = "/run/current-system/sw/bin/ssh-keygen";
          };
        };

        ssh = {
          enable = true;
          enableDefaultConfig = false;
          matchBlocks."*".compression = true;
        };
      };
    };
  };
}
