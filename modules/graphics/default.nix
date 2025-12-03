{ pkgs, ... }: {
  imports = [
    ./intel-arc.nix
  ];

  environment.systemPackages = with pkgs; [
    pciutils
  ];
}
