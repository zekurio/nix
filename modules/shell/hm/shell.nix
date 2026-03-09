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
      atuin
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
      fishPlugins.pure
      fishPlugins.z
    ];

    sops = {
      age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
      defaultSopsFile = ../../../secrets/zekurio-shell.yaml;
      secrets.gh-token = {};
    };

    programs = {
      gh = {
        enable = true;
        settings = {
          git_protocol = "ssh";
        };
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

      fish = {
        enable = true;

        interactiveShellInit = ''
          set fish_greeting
          fish_add_path "/home/zekurio/.local/bin"
          atuin init fish | source

          # Load GH_TOKEN from sops-decrypted secret
          if test -r "${config.sops.secrets.gh-token.path}"
            set -gx GH_TOKEN (string trim (cat "${config.sops.secrets.gh-token.path}"))
          end
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
        package = inputs."opencode-nix".packages.${pkgs.system}.opencode;

        settings = {
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
              template = "Move our changes to a new branch, stage all changes, commit them following the project's commit guidelines, and push the changes using the gh CLI. Follow the project's contribution guidelines for PRs, or look up past PRs for examples.";
              description = "Commit and push all changes to the repository with a PR";
              agent = "build";
            };
            resolve = {
              template = "PR $1 has received comments from reviewers. Address them, commit the changes, and push the updated branch to resolve them. Use the gh CLI to resolve them in gh as well.";
              description = "Resolve a review comments";
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
