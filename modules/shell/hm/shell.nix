{
  pkgs,
  lib,
  config,
  ...
}: let
  cfg = config.modules.hm.shell;
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
    home.packages = with pkgs; [
      age
      atuin
      bat
      btop
      eza
      envsubst
      git
      gh
      jq
      nil
      nixd
      ripgrep
      sops
      uv
      zellij

      # fish stuff
      fishPlugins.pure
      fishPlugins.z
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

        interactiveShellInit = ''
          set fish_greeting
          fish_add_path "/home/zekurio/.local/bin"
          atuin init fish | source
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

        settings = {
          command = {
            ship = {
              template = "If not in a feature branch, switch to a new branch and stage all changes. Commit the changes following the project's commit guidelines. Push the changes and file a pull request using the github CLI.";
              description = "Commit and push all changes to the repository with a PR";
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
            setEnv = {
              TERM = "xterm-256color";
            };
          };
        };
      };
    };
  };
}
