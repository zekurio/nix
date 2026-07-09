{inputs, ...}: {
  imports = [
    inputs.catppuccin.homeModules.catppuccin
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

  # Catppuccin Frappé/Blue across the CLI. autoEnable is off so only the
  # ports enabled next to each program are themed; flavor and accent cascade to
  # every port.
  catppuccin = {
    enable = true;
    autoEnable = false;
    flavor = "frappe";
    accent = "blue";
  };
}
