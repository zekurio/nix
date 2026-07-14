{inputs, ...}: {
  imports = [
    inputs.catppuccin.homeModules.catppuccin
    ./agents
    ./appearance
    ./dev.nix
    ./eza.nix
    ./fish.nix
    ./ghostty.nix
    ./packages.nix
    ./prompt.nix
  ];

  programs = {
    bat.enable = true;
    btop.enable = true;
  };

  # autoEnable is off so only the ports enabled next to each program are
  # themed. Appearance-aware CLI ports are managed by appearance/default.nix.
  catppuccin =
    {
      enable = true;
      autoEnable = false;
    }
    // import ../../../palette.nix;
}
