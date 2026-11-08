{pkgs, ...}: {
  programs.niri.enable = true;

  environment.systemPackages = [
    # niri runs X11 clients through xwayland-satellite, which it starts from
    # PATH at login. Without it niri disables X11 support for the session,
    # and X11-only clients such as Steam cannot open a window.
    pkgs.xwayland-satellite
  ];

  # niri implements GlobalShortcuts through xdg-desktop-portal-gnome, which
  # hands the binding dialog to GNOME Settings' D-Bus-activated provider.
  services.dbus.packages = [pkgs.gnome-control-center];
}
