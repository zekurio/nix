{pkgs, ...}: let
  # Bibata's rounded, flat shapes are modelled on Material Design's cursors.
  name = "Bibata-Modern-Classic";
  size = 24;
in {
  home-manager.users.zekurio = {
    # Sets XCURSOR_THEME and ~/.icons/default for apps that read neither
    # gsettings nor niri. dux-shell.nix passes the name on to niri.
    home.pointerCursor = {
      enable = true;
      package = pkgs.bibata-cursors;
      inherit name size;
    };
    # GTK apps and DMS's cursor settings read this key. pointerCursor.gtk
    # would set it too, but it turns on home-manager's GTK module, which
    # stops at the settings.ini files Plasma left behind.
    dconf.settings."org/gnome/desktop/interface" = {
      cursor-theme = name;
      cursor-size = size;
    };
  };
}
