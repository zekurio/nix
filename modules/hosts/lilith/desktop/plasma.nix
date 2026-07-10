{
  inputs,
  lib,
  pkgs,
  ...
}: {
  services = {
    desktopManager.plasma6 = {
      enable = true;
      enableQt5Integration = false;
    };

    displayManager = {
      defaultSession = "plasma";
      plasma-login-manager.enable = true;
      sddm.enable = lib.mkForce false;
    };

    xserver.xkb.layout = "at";
  };

  programs.kde-pim.enable = false;

  environment.systemPackages = [
    pkgs.klassy
  ];

  home-manager.sharedModules = [
    inputs.plasma-manager.homeModules.plasma-manager
  ];

  home-manager.users.zekurio.programs.plasma = {
    enable = true;

    # Only the keys set here (and in theme.nix) are managed; everything else
    # in ~/.config is still mutable. To make the whole desktop reproducible:
    # capture the current state on lilith with
    #   nix run github:nix-community/plasma-manager -- rc2nix
    # promote the parts worth keeping into this module, then flip
    # overrideConfig on. From that point every unmanaged setting resets to
    # its default on login, so only do it after the capture pass.
    overrideConfig = false;

    input.keyboard.layouts = [{layout = "at";}];
  };
}
