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

        fish = {
          enable = true;
        };

        starship = {
          enable = true;
          enableFishIntegration = true;
          settings = {
            "$schema" = "https://starship.rs/config-schema.json";
            format = "$username$hostname$directory$git_branch$git_state$git_status$cmd_duration$line_break$python$character";

            directory.style = "blue";

            character = {
              success_symbol = "[❯](purple)";
              error_symbol = "[❯](red)";
              vimcmd_symbol = "[❮](green)";
            };

            git_branch = {
              format = "[$branch]($style)";
              style = "bright-black";
            };

            git_status = {
              format = "[[(*$conflicted$untracked$modified$staged$renamed$deleted)](218) ($ahead_behind$stashed)]($style)";
              style = "cyan";
              conflicted = "​";
              untracked = "​";
              modified = "​";
              staged = "​";
              renamed = "​";
              deleted = "​";
              stashed = "≡";
            };

            git_state = {
              format = "\\([$state( $progress_current/$progress_total)]($style)\\) ";
              style = "bright-black";
            };

            cmd_duration = {
              format = "[$duration]($style) ";
              style = "yellow";
            };

            python = {
              format = "[$virtualenv]($style) ";
              style = "bright-black";
              detect_extensions = [ ];
              detect_files = [ ];
            };
          };
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
