{inputs, ...}: {
  flake.modules.nixos.adam = {pkgs, ...}: {
    imports = [inputs.sops-nix.nixosModules.sops];

    # The age key is hand-placed during bootstrap (see README) and
    # deliberately not generated on the host.
    sops = {
      # The activation script's unit restart list is deprecated in NixOS 26.11.
      useSystemdActivation = true;
      # sops-nix master builds sops-install-secrets with buildGo125Module,
      # which nixpkgs removed on 2026-09-15 (Go 1.25 EOL) as a throwing alias.
      # Call sops-nix's package expression with that builder shimmed to the
      # current one so its own vendorHash stays in charge. Drop this when
      # upstream bumps the builder.
      package =
        (pkgs.callPackage "${inputs.sops-nix}" {
          pkgs = pkgs.extend (_: prev: {buildGo125Module = prev.buildGo126Module;});
        }).sops-install-secrets;
      defaultSopsFile = ../../../secrets/adam.yaml;
      age = {
        keyFile = "/var/lib/sops-nix/key.txt";
        generateKey = false;
        sshKeyPaths = [];
      };
      gnupg.sshKeyPaths = [];
    };
  };
}
