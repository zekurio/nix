let
  sshKey = "/home/zekurio/.ssh/id_ed25519";
in {
  # sshd itself (hardened defaults + pinned keys) comes from modules.ssh.
  services.openssh.settings.AllowAgentForwarding = true;
  # The knot takes 22, because tangled.org's clone URLs never carry a port
  # (modules/homelab/services/knot). Flint forwards nothing to 2200, so
  # sshd answers the LAN and the tailnet only.
  services.openssh.ports = [2200];

  home-manager.users.zekurio = {
    programs.keychain = {
      enable = true;
      keys = [sshKey];
    };

    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;
      settings."github.com" = {
        IdentityFile = sshKey;
        IdentitiesOnly = true;
        AddKeysToAgent = "yes";
      };
    };

    programs.git.signing.key = sshKey;
  };
}
