{
  imports = [
    ./dev.nix
    ./fish.nix
    ./packages.nix
    ./prompt.nix
  ];

  programs = {
    bat.enable = true;
    btop.enable = true;
  };
}
