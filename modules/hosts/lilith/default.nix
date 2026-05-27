{inputs, ...}: {
  imports = [
    inputs.disko.nixosModules.disko
    ../_common/desktop
    ../_common/desktop/kde.nix
    ./disko.nix
    ./coolercontrol.nix
    ./configuration.nix
  ];
}
