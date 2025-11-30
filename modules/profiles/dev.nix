{
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (lib)
    hasAttrByPath
    mkAfter
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  cfg = config.profiles.dev;

  basePackages =
    pkgs': with pkgs'; [
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
    enable = mkEnableOption "Development profile powered by Home Manager" // {
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

  config = mkIf cfg.enable {
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

    home-manager.users.${cfg.user} =
      { pkgs, ... }:
      {
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
      pkgs.unstable.opencode
    ];
  };
}
