{
  pkgs,
  lib,
  config,
  inputs,
  ...
}: let
  cfg = config.modules.hm.shell;
  signingKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOCcQoZiY9wkJ+U93isE8B3CKLmzL7TPzVh3ugE1WPJq";
  opencodeConfigDir = ../../../config/opencode;
in {
  options.modules.hm.shell = {
    enable =
      lib.mkEnableOption "shell configuration"
      // {
        default = true;
      };
  };

  config = lib.mkIf cfg.enable {
    home.file.".config/git/allowed_signers".text = ''
      git@zekurio.xyz ${signingKey}
    '';
    home.file.".config/opencode/skills/frontend-design/SKILL.md".source =
      opencodeConfigDir + /skills/frontend-design/SKILL.md;

    home.sessionPath = [
      "$HOME/.local/bin"
    ];

    home.packages = with pkgs; [
      age
      bat
      btop
      eza
      envsubst
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
        enableZshIntegration = true;
      };

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
        enableCompletion = true;
        syntaxHighlighting.enable = true;

        oh-my-zsh = {
          enable = true;
          theme = "af-magic";
          plugins = [
            "git"
          ];
        };

      };

      carapace = {
        enable = true;
        enableZshIntegration = true;
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

      opencode = {
        enable = true;
        package = inputs."opencode-nix".packages.${pkgs.stdenv.hostPlatform.system}.opencode;

        settings = {
          plugin = [
            "@simonwjackson/opencode-direnv"
          ];

          server = {
            port = 4096;
            hostname = "127.0.0.1";
            mdns = false;
          };

          permission = {
            bash = {
              "*" = "allow"; # might end up dangerous
              "rm *" = "ask";
            };
            skill = {
              "*" = "allow";
            };
          };

          command = {
            pr = {
              template = "Move our changes to a new branch, stage all changes, commit them following the project's commit guidelines, and push the changes using the gh CLI. Follow the project's contribution guidelines for PRs, or look up past PRs for examples before creating a draft PR using the gh CLI.";
              description = "Commit and push all changes to remote, file a draft PR as well";
              agent = "build";
            };
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
