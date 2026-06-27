{
  imports = [
    ./dev.nix
    ./fish.nix
    ./ghostty.nix
    ./packages.nix
    ./prompt.nix
  ];

  programs = {
    bat.enable = true;
    btop.enable = true;
  };
}
