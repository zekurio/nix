{pkgs, ...}: {
  environment.systemPackages = [
    pkgs.catppuccin-kde
    pkgs.klassy
  ];

  home-manager.users.zekurio = {
    qt.kde.settings = {
      kdeglobals = {
        General.ColorScheme = "CatppuccinFrappeBlue";
        KDE.LookAndFeelPackage = "Catppuccin-Frappe-Blue";
      };

      kwinrc."org.kde.kdecoration2" = {
        library = "org.kde.klassy";
        theme = "";
      };
    };
  };
}
