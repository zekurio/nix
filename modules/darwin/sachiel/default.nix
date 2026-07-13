{pkgs, ...}: {
  imports = [
    ./homebrew.nix
  ];

  environment.systemPackages = with pkgs; [
    openssh
  ];
}
