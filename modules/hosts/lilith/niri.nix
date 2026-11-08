{pkgs, ...}: {
  programs.niri.enable = true;

  # niri implements GlobalShortcuts through xdg-desktop-portal-gnome, which
  # hands the binding dialog to GNOME Settings' D-Bus-activated provider.
  services.dbus.packages = [pkgs.gnome-control-center];
}
