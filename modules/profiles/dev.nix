{ lib
, pkgs
, config
, ...
}:
let
  inherit
    (lib)
    hasAttrByPath
    mkAfter
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  cfg = config.profiles.dev;

  basePackages = pkgs':
    with pkgs'; [
      age
      bat
      btop
      eza
      envsubst
      fastfetch
      git
      jq
      nil
      nixd
      sops
      zellij
    ];
in
{
  options.profiles.dev = {
    enable =
      mkEnableOption "Development profile powered by Home Manager"
      // {
        default = true;
      };

    user = mkOption {
      type = types.str;
      default = "zekurio";
      description = "Primary user account managed by the development profile.";
    };

    stateVersion = mkOption {
      type = types.str;
      default = "25.05";
      description = "Home Manager stateVersion for the managed user.";
    };
  };

  config =
    mkIf cfg.enable {
      assertions = [
        {
          assertion = hasAttrByPath [ cfg.user ] config.users.users;
          message = "profiles.dev.user must reference an existing entry in users.users";
        }
      ];

      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        backupFileExtension = "backup";
      };

      home-manager.users.${cfg.user} = { pkgs, ... }: {
        home = {
          username = cfg.user;
          homeDirectory = "/home/${cfg.user}";
          stateVersion = cfg.stateVersion;
          enableNixpkgsReleaseCheck = false;
          packages = basePackages pkgs;
        };

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
              set -g fish_greeting
            '';
            plugins = [ ];
          };

          starship = {
            enable = true;
            enableFishIntegration = true;
            settings = {
              add_newline = false;
              format = ''
                $python$directory$character
              '';
              right_format = ''
                $status$all
              '';

              username = {
                format = "[$user]($style) ";
                show_always = true;
                style_user = "bold yellow";
              };

              hostname = {
                format = "@[$ssh_symbol$hostname]($style) ";
                ssh_only = true;
                ssh_symbol = "🌐 ";
                style = "bold cyan";
              };

              character = {
                success_symbol = "[❯](red)[❯](yellow)[❯](green)";
                error_symbol = "[❯](red)[❯](yellow)[❯](green)";
                vicmd_symbol = "[❮](green)[❮](yellow)[❮](red)";
              };

              git_branch = {
                format = "[$branch]($style) ";
                style = "bold green";
              };

              python.format = ''\($virtualenv\) '';

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

              cmd_duration.format = "[$duration]($style) ";

              line_break.disabled = true;

              status = {
                disabled = false;
                symbol = "✘ ";
              };
            };
          };

          git = {
            enable = true;
            settings = {
              user.name = "Michael Schwieger";
              user.email = "git@zekurio.xyz";
              init.defaultBranch = "main";
              pull.rebase = true;
              rebase.autoStash = true;
              gpg.format = "ssh";
              gpg.ssh.program = "${pkgs.openssh}/bin/ssh-keygen";
              user.signingKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOCcQoZiY9wkJ+U93isE8B3CKLmzL7TPzVh3ugE1WPJq";
              commit.gpgSign = true;
            };
          };

          ssh = {
            enable = true;
            enableDefaultConfig = false;
            matchBlocks."*".compression = true;
          };
        };
      };

      environment.systemPackages = mkAfter [
        pkgs.gh
        pkgs.unstable.codex
        pkgs.unstable.opencode
      ];
    };
}
