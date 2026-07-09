{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (config.catppuccin) accent flavor;
  flavorTitle = lib.toSentenceCase flavor;
  accentTitle = lib.toSentenceCase accent;
  colorScheme = "Catppuccin${flavorTitle}${accentTitle}";
  cursorTheme = "catppuccin-${flavor}-${accent}-cursors";
  lookAndFeelPackage = "Catppuccin-${flavorTitle}-${accentTitle}";
  splashTheme = "${lookAndFeelPackage}-splash";
  windowDecorationTheme = "__aurorae__svg__Catppuccin${flavorTitle}-Modern";

  kdeTheme = pkgs.catppuccin-kde.override {
    flavour = [flavor];
    accents = [accent];
  };
  papirusFolders = pkgs.catppuccin-papirus-folders.override {
    inherit flavor accent;
  };

  kdeSettings = {
    kdeglobals = {
      General.ColorScheme = colorScheme;
      Icons.Theme = "Papirus-Dark";
      KDE.LookAndFeelPackage = lookAndFeelPackage;
    };
    kcminputrc.Mouse.cursorTheme = cursorTheme;
    kscreenlockerrc.Greeter.LnFPackage = lookAndFeelPackage;
    ksplashrc.KSplash.Theme = splashTheme;
    kwinrc."org.kde.kdecoration2" = {
      ButtonsOnLeft = "";
      ButtonsOnRight = "IAX";
      library = "org.kde.kwin.aurorae";
      theme = windowDecorationTheme;
    };
    plasmarc.Theme.name = "default";
  };

  ini = pkgs.formats.ini {};
in {
  catppuccin.cursors = {
    enable = true;
    inherit accent flavor;
  };

  environment = {
    systemPackages = [
      kdeTheme
      papirusFolders
      pkgs.catppuccin-kvantum
    ];

    # Plasma Login Manager runs as the plasmalogin user and reads KConfig from
    # the system XDG config dirs before any user-specific files exist.
    etc = {
      "xdg/kdeglobals".source = ini.generate "catppuccin-kdeglobals" kdeSettings.kdeglobals;
      "xdg/kcminputrc".source = ini.generate "catppuccin-kcminputrc" kdeSettings.kcminputrc;
      "xdg/kscreenlockerrc".source = ini.generate "catppuccin-kscreenlockerrc" kdeSettings.kscreenlockerrc;
      "xdg/ksplashrc".source = ini.generate "catppuccin-ksplashrc" kdeSettings.ksplashrc;
      "xdg/kwinrc".source = ini.generate "catppuccin-kwinrc" kdeSettings.kwinrc;
      "xdg/plasmarc".source = ini.generate "catppuccin-plasmarc" kdeSettings.plasmarc;
    };
  };

  home-manager.users.zekurio = {
    home.pointerCursor.enable = true;

    catppuccin = {
      inherit accent flavor;

      cursors = {
        enable = true;
        inherit accent flavor;
      };
      gtk.icon = {
        enable = true;
        inherit accent flavor;
      };
      kvantum = {
        enable = true;
        inherit accent flavor;
      };
    };

    gtk = {
      enable = true;
      colorScheme = "dark";
    };

    qt = {
      enable = true;
      platformTheme.name = "kde";
      style.name = "kvantum";
      kde.settings = kdeSettings;
    };
  };
}
