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
            settings = builtins.fromTOML ''
              format = """
              $username\
              $hostname\
              $directory\
              $git_branch\
              $git_state\
              $git_status\
              $cmd_duration\
              $line_break\
              $python\
              $character"""

              [directory]
              style = "blue"

              [character]
              success_symbol = "[❯](purple)"
              error_symbol = "[❯](red)"
              vimcmd_symbol = "[❮](green)"

              [git_branch]
              format = "[$branch]($style)"
              style = "bright-black"

              [git_status]
              format = "[[(*$conflicted$untracked$modified$staged$renamed$deleted)](218) ($ahead_behind$stashed)]($style)"
              style = "cyan"
              conflicted = "​"
              untracked = "​"
              modified = "​"
              staged = "​"
              renamed = "​"
              deleted = "​"
              stashed = "≡"

              [git_state]
              format = '\([$state( $progress_current/$progress_total)]($style)\) '
              style = "bright-black"

              [cmd_duration]
              format = "[$duration]($style) "
              style = "yellow"

              [python]
              format = "[$virtualenv]($style) "
              style = "bright-black"
              detect_extensions = []
              detect_files = []
            '';
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
