{
  # Hyprland itself starts hyprland-session.target, which binds
  # graphical-session.target, so dms.service and xembsni start without UWSM.
  # Hyprland's package ships the target under share/systemd/user, which the
  # user manager reads from the system profile.
  programs.hyprland.enable = true;

  # programs.niri turned the keyring and its Secret portal on; Hyprland's
  # module does not. Defining config.hyprland makes xdg-desktop-portal ignore
  # Hyprland's own portals.conf, so its default backends are repeated here.
  services.gnome.gnome-keyring.enable = true;
  xdg.portal.config.hyprland = {
    default = ["hyprland" "gtk"];
    "org.freedesktop.impl.portal.Secret" = "gnome-keyring";
  };
}
