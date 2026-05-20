{
  config,
  osConfig,
  pkgs,
  ...
}: let
  lilithSigningKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOCcQoZiY9wkJ+U93isE8B3CKLmzL7TPzVh3ugE1WPJq";
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
    if osConfig.wsl.enable or false
    then "/mnt/c/Users/zekurio/AppData/Local/Microsoft/WindowsApps/op-ssh-sign-wsl.exe"
    else "${pkgs.openssh}/bin/ssh-keygen";
in {
  home.file.".config/git/allowed_signers".text = ''
    git@zekurio.me ${lilithSigningKey}
    git@zekurio.me ${sachielSigningKey}
  '';

  programs.git = {
    enable = true;
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
}
