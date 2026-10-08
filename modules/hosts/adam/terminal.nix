{
  flake.modules.nixos.adam = {pkgs, ...}: {
    environment.systemPackages = [pkgs.kitty.terminfo];

    # Enable truecolor output for terminal applications.
    home-manager.users.zekurio.home.sessionVariables.COLORTERM = "truecolor";
  };
}
