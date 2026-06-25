{inputs, ...}: {
  imports = [
    inputs.disko.nixosModules.disko
    ./disko.nix
    ./configuration.nix
    ./desktop-apps.nix
  ];
}
