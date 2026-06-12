{
  imports = [
    ./dev.nix
    ./nushell.nix
    ./packages.nix
    ./prompt.nix
  ];

  catppuccin = {
    bat = {
      enable = true;
      flavor = "frappe";
    };

    btop = {
      enable = true;
      flavor = "frappe";
    };
  };

  programs = {
    bat.enable = true;
    btop.enable = true;
  };
}
