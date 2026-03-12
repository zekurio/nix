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
  opencodeServicePath = lib.concatStringsSep ":" [
    "${config.home.homeDirectory}/.local/bin"
    "/etc/profiles/per-user/${config.home.username}/bin"
    "/run/wrappers/bin"
    "/run/current-system/sw/bin"
    "/nix/var/nix/profiles/default/bin"
    "/nix/profile/bin"
  ];
  opencodeWebStart = pkgs.writeShellScript "opencode-web-start" ''
    export PATH="${opencodeServicePath}:$PATH"

    if [ -r "${config.sops.secrets.gh-token.path}" ]; then
      export GH_TOKEN="$(<"${config.sops.secrets.gh-token.path}")"
    fi

    exec "${config.programs.opencode.package}/bin/opencode" web --hostname 127.0.0.1 --port 4096
  '';
in {
  options.modules.hm.shell = {
    enable =
      lib.mkEnableOption "shell configuration"
      // {
        default = true;
      };

    opencodeWeb.enable = lib.mkEnableOption "OpenCode web user service";
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

    sops = {
      age = {
        keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
        generateKey = false;
        sshKeyPaths = [];
      };
      gnupg.sshKeyPaths = [];
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

        initContent = lib.mkBefore ''
          if [[ -r "${config.sops.secrets.gh-token.path}" ]]; then
            export GH_TOKEN="$(<"${config.sops.secrets.gh-token.path}")"
          fi
        '';
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

    systemd.user.services.opencode-web = lib.mkIf cfg.opencodeWeb.enable {
      Unit = {
        Description = "OpenCode web server";
        After = ["default.target"];
      };

      Service = {
        ExecStart = opencodeWebStart;
        Environment = ["BROWSER=${pkgs.coreutils}/bin/true"];
        Restart = "on-failure";
        RestartSec = 5;
        WorkingDirectory = config.home.homeDirectory;
      };

      Install.WantedBy = ["default.target"];
    };
  };
}
