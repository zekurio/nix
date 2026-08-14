{
  flake.modules.nixos.lilith = {pkgs, ...}: {
    environment.systemPackages = [
      (pkgs.callPackage ./_t3code-nightly.nix {})
    ];
  };
}
