{
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
    pkgs.papirus-icon-theme
  ];

  home-manager.users.zekurio.qt.kde.settings.kdeglobals.Icons.Theme = "Papirus-Dark";
}
