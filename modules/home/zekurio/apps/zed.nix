{
  # Config/theme only; the binary comes from the host (system package on
  # NixOS, Homebrew cask on macOS). Flavor and accent cascade from the
  # global catppuccin settings.
  programs.zed-editor = {
    enable = true;
    package = null;
  };

  catppuccin.zed = {
    enable = true;
    icons.enable = true;
  };
}
