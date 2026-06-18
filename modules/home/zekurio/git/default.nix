{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}: let
  cfg = config.home.onepasswordSsh;
  adamSigningKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGoFjRGxdJUuPwS0wXCOmcvf8rOgeSGWtWQaCnLcRS4N";
  lilithSigningKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMPfrsYAgx8QD5Kmic1AfdKC6vEV9v1ZnitfDp/c+PrQ";
  sachielSigningKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDxyfT6gCDvcoUXL6Sln2Gfqihgo4Cx4ggoXFIpxCZpq";
  gitSshSigningKeyCommand = pkgs.writeShellApplication {
    name = "git-ssh-signing-key";
    runtimeInputs = [pkgs.openssh];
    text = ''
      agent_keys="$(ssh-add -L 2>/dev/null || true)"

      case "$agent_keys" in
        *"${lilithSigningKey}"*)
          printf '%s\n' "key::${lilithSigningKey}"
          ;;
        *"${sachielSigningKey}"*)
          printf '%s\n' "key::${sachielSigningKey}"
          ;;
        *)
          printf '%s\n' "No configured Git SSH signing key found in SSH agent" >&2
          exit 1
          ;;
      esac
    '';
  };
  sshSigningProgram =
    if cfg.enable
    then "${pkgs._1password-gui}/bin/op-ssh-sign"
    else if osConfig.wsl.enable or false
    then "/mnt/c/Users/zekurio/AppData/Local/Microsoft/WindowsApps/op-ssh-sign-wsl.exe"
    else "${pkgs.openssh}/bin/ssh-keygen";
in {
  options.home.onepasswordSsh = {
    enable = lib.mkEnableOption "1Password SSH agent integration";

    vault = lib.mkOption {
      type = lib.types.str;
      default = "Persönlich";
      description = "1Password vault that contains the SSH key item.";
    };

    item = lib.mkOption {
      type = lib.types.str;
      description = "1Password item to expose through the SSH agent.";
    };

    signingKey = lib.mkOption {
      type = lib.types.str;
      description = "SSH public key used for Git commit signing.";
    };
  };

  config = {
    home.file.".config/git/allowed_signers".text = ''
      git@zekurio.me ${adamSigningKey}
      git@zekurio.me ${lilithSigningKey}
      git@zekurio.me ${sachielSigningKey}
    '';

    xdg.configFile."1Password/ssh/agent.toml" = lib.mkIf cfg.enable {
      text = ''
        [[ssh-keys]]
        vault = "${cfg.vault}"
        item = "${cfg.item}"
      '';
    };

    home.sessionVariables = lib.mkIf cfg.enable {
      SSH_AUTH_SOCK = "${config.home.homeDirectory}/.1password/agent.sock";
    };

    programs.ssh = lib.mkIf cfg.enable {
      enable = true;
      enableDefaultConfig = false;
      settings = {
        "*" = {
          IdentityAgent = "~/.1password/agent.sock";
        };
        adam = {
          HostName = "adam.lan";
          User = "zekurio";
          ForwardAgent = true;
        };
        "adam.lan" = {
          User = "zekurio";
          ForwardAgent = true;
        };
      };
    };

    programs.git = {
      enable = true;
      signing = {
        signByDefault = true;
      };
      settings = {
        user = {
          name = "Michael Schwieger";
          email = "git@zekurio.me";
          signingkey = lib.mkIf cfg.enable cfg.signingKey;
        };
        init.defaultBranch = "main";
        pull.rebase = true;
        rebase.autoStash = true;
        gpg.format = "ssh";
        gpg.ssh.allowedSignersFile = "${config.home.homeDirectory}/.config/git/allowed_signers";
        gpg.ssh.defaultKeyCommand = lib.mkIf (!cfg.enable) "${gitSshSigningKeyCommand}/bin/git-ssh-signing-key";
        "gpg \"ssh\"".program = sshSigningProgram;
      };
    };
  };
}
