{
  pkgs,
  lib,
  config,
  inputs,
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
    home.file.".config/git/allowed_signers".text = ''
      git@zekurio.xyz ${signingKey}
    '';

    home.sessionPath = [
      "$HOME/.local/bin"
    ];

    home.packages = with pkgs; [
      age
      bat
      btop
      inputs.codex-cli-nix.packages.${pkgs.stdenv.hostPlatform.system}.default
      envsubst
      gh
      git
      jq
      nil
      nixd
      ripgrep
      sops
      uv
      zellij
    ];

    programs = {
      atuin = {
        enable = true;
        enableNushellIntegration = true;
      };

      direnv = {
        enable = true;
        enableNushellIntegration = true;
        nix-direnv.enable = true;
      };

      nushell = {
        enable = true;
        plugins = with pkgs.nushellPlugins; [
          highlight
        ];
        settings = {
          show_banner = false;
          history.file_format = "sqlite";
        };
      };

      carapace = {
        enable = true;
        enableNushellIntegration = true;
      };

      starship = {
        enable = true;
        enableNushellIntegration = true;
        settings = {
          add_newline = false;
          format = "$python$directory$character";
          right_format = "$status$git_branch$git_status";

          character = {
            success_symbol = "[❯](red)[❯](yellow)[❯](green)";
            error_symbol = "[❯](red)[❯](yellow)[❯](green)";
            vicmd_symbol = "[❮](green)[❮](yellow)[❮](red)";
          };

          git_branch = {
            format = "[$branch]($style) ";
            style = "bold green";
          };

          python = {
            format = "[(\\($virtualenv\\) )]($style)";
            style = "white";
          };

          git_status = {
            format = "$all_status$ahead_behind ";
            ahead = "[⬆](bold purple) ";
            behind = "[⬇](bold purple) ";
            staged = "[✚](green) ";
            deleted = "[✖](red) ";
            renamed = "[➜](purple) ";
            stashed = "[✭](cyan) ";
            untracked = "[◼](white) ";
            modified = "[✱](blue) ";
            conflicted = "[═](yellow) ";
            diverged = "⇕ ";
            up_to_date = "";
          };

          directory = {
            style = "blue";
            truncation_length = 1;
            truncation_symbol = "";
            fish_style_pwd_dir_length = 1;
          };

          cmd_duration = {
            format = "[$duration]($style) ";
          };

          line_break.disabled = true;

          status = {
            disabled = false;
            symbol = "✘ ";
          };
        };
      };

      zoxide = {
        enable = true;
        enableNushellIntegration = true;
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
          gpg.ssh.allowedSignersFile = "${config.home.homeDirectory}/.config/git/allowed_signers";
          "gpg \"ssh\"".program = "/run/current-system/sw/bin/ssh-keygen";
        };
      };

      jujutsu = {
        enable = true;
        settings = {
          user = {
            name = "Michael Schwieger";
            email = "git@zekurio.xyz";
          };
          signing = {
            behavior = "own";
            backend = "ssh";
            key = signingKey;
            backends.ssh.program = "/run/current-system/sw/bin/ssh-keygen";
          };
        };
      };

      ssh = {
        enable = true;
        enableDefaultConfig = false;
        matchBlocks = {
          "*".compression = true;
          "adam" = {
            hostname = "adam.local";
            user = "zekurio";
            forwardAgent = true;
          };
          "lilith" = {
            hostname = "46.224.128.128";
            user = "zekurio";
            forwardAgent = true;
          };
        };
      };
    };
  };
}
