{pkgs, ...}: {
  environment = {
    systemPackages = with pkgs; [
      # DMS recolours its own copy of adw-gtk3 for GTK 3 apps.
      adw-gtk3
      # Papirus ships blue folders; red is its folder colour nearest the accent.
      (papirus-icon-theme.override {color = "red";})
      qtengine
    ];
    # DMS rewrites qtengine's colour scheme and icon theme on every theme
    # change, and running Qt 6 apps repaint without a restart.
    sessionVariables.QT_QPA_PLATFORMTHEME = "qtengine";
  };
  # Puts the system profile's Qt plugins, qtengine among them, on
  # QT_PLUGIN_PATH.
  qt.enable = true;
  # Papirus is all SVG. GTK apps that nixpkgs does not wrap find the SVG
  # loader only through the GDK_PIXBUF_MODULE_FILE this sets.
  programs.gdk-pixbuf.modulePackages = [pkgs.librsvg];
}
