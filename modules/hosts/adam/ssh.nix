{
  flake.modules.nixos.adam = let
    sshKey = "/home/zekurio/.ssh/id_ed25519";
  in {
    # sshd itself (hardened defaults + pinned keys) comes from modules.ssh.
    services.openssh.settings.AllowAgentForwarding = true;

    home-manager.users.zekurio = {
      programs.keychain = {
        enable = true;
        enableFishIntegration = true;
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

      programs.git.settings.user.signingkey = sshKey;
    };
  };
}
