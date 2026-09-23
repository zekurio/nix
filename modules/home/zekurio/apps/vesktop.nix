{
  flake.modules.homeManager.zekurio = {
    # The binary comes from the host: a NixOS package or Homebrew cask.
    programs.vesktop = {
      enable = true;
      package = null;
    };
  };
}
