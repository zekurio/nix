{
  config,
  lib,
  pkgs,
  ...
}: let
  adamSigningKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGoFjRGxdJUuPwS0wXCOmcvf8rOgeSGWtWQaCnLcRS4N";
  sachielSigningKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDxyfT6gCDvcoUXL6Sln2Gfqihgo4Cx4ggoXFIpxCZpq";
  signingKeys = [
    adamSigningKey
    sachielSigningKey
  ];
  gitSshSigningKeyCommand = pkgs.writeShellApplication {
    name = "git-ssh-signing-key";
    runtimeInputs = [pkgs.openssh];
    text = ''
      agent_keys="$(ssh-add -L 2>/dev/null || true)"

      case "$agent_keys" in
        ${lib.concatMapStrings (key: ''
          *"${key}"*)
            printf '%s\n' "key::${key}"
            ;;
        '')
        signingKeys}
        *)
          printf '%s\n' "No configured Git SSH signing key found in SSH agent" >&2
          exit 1
          ;;
      esac
    '';
  };
  sshSigningProgram = "${pkgs.openssh}/bin/ssh-keygen";
in {
  config = {
    home.file.".config/git/allowed_signers".text =
      lib.concatMapStringsSep "\n" (key: "git@zekurio.me ${key}") signingKeys
      + "\n";

    programs.git = {
      enable = true;
      lfs.enable = true;
      signing = {
        signByDefault = true;
      };
      settings = {
        user = {
          name = "Michael Schwieger";
          email = "git@zekurio.me";
        };
        init.defaultBranch = "main";
        pull.rebase = true;
        rebase.autoStash = true;
        gpg.format = "ssh";
        gpg.ssh.allowedSignersFile = "${config.home.homeDirectory}/.config/git/allowed_signers";
        gpg.ssh.defaultKeyCommand = "${gitSshSigningKeyCommand}/bin/git-ssh-signing-key";
        "gpg \"ssh\"".program = sshSigningProgram;
      };
    };

    programs.jujutsu = {
      enable = true;
      settings = {
        user = {
          name = "Michael Schwieger";
          email = "git@zekurio.me";
        };

        signing = {
          behavior = "drop";
          backend = "ssh";
          key = "${config.home.homeDirectory}/.ssh/id_ed25519.pub";
          backends.ssh = {
            program = "${pkgs.openssh}/bin/ssh-keygen";
            "allowed-signers" = "${config.home.homeDirectory}/.config/git/allowed_signers";
          };
        };

        git = {
          "sign-on-push" = true;
        };
      };
    };

    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;
      settings = {
        "*" =
          {
            AddKeysToAgent = "yes";
            Compression = false;
            ControlMaster = "auto";
            ControlPath = "~/.ssh/master-%r@%n:%p";
            ControlPersist = "10m";
            HashKnownHosts = true;
            ServerAliveCountMax = 3;
            ServerAliveInterval = 30;
            UserKnownHostsFile = "~/.ssh/known_hosts";
          }
          // lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
            IgnoreUnknown = "UseKeychain";
            UseKeychain = "yes";
          };

        "github.com" = {
          AddKeysToAgent = lib.mkDefault "yes";
          HostName = lib.mkDefault "github.com";
          IdentityFile = lib.mkDefault "~/.ssh/id_ed25519";
          User = lib.mkDefault "git";
        };

        adam = {
          HostName = "10.0.0.2";
          User = "zekurio";
          IdentityFile = "~/.ssh/id_ed25519";
        };
      };
    };
  };
}
