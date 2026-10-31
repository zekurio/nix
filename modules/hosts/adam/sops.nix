{inputs, ...}: {
  imports = [inputs.sops-nix.nixosModules.sops];

  # The age key is hand-placed during bootstrap (see README) and
  # deliberately not generated on the host.
  sops = {
    # The activation script's unit restart list is deprecated in NixOS 26.11.
    useSystemdActivation = true;
    defaultSopsFile = ../../../secrets/adam.yaml;
    age = {
      keyFile = "/var/lib/sops-nix/key.txt";
      generateKey = false;
      sshKeyPaths = [];
    };
    gnupg.sshKeyPaths = [];
  };
}
