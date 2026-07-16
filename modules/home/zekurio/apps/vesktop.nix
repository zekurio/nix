{
  flake.modules.homeManager.zekurio = {
    # Config/theme only; the binary comes from the host (system package on
    # NixOS, Homebrew cask on macOS). Flavor and accent cascade from the
    # global catppuccin settings.
    programs.vesktop = {
      enable = true;
      package = null;
    };

    catppuccin.vesktop.enable = true;
  };
}
