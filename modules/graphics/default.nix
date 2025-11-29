{ pkgs, ... }: {
  imports = [
    ./amd.nix
    ./intel-arc.nix
  ];

  environment.systemPackages = with pkgs; [
    pciutils
  ];
}
