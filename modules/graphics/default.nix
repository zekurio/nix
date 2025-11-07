{ pkgs, ... }: {
  imports = [
    ./amd.nix
    ./amd-nvidia.nix
    ./intel-arc.nix
    ./nvidia.nix
  ];

  environment.systemPackages = with pkgs; [
    pciutils
  ];
}
