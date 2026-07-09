{
  config,
  inputs,
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

  wallpaperImage = ../../../../assets/wallpaper.jpg;
  faceImage = ../../../../assets/face.png;

  # Latte is installed alongside the active flavor so Catppuccin-Latte-Blue is
  # selectable from System Settings without changing the default look.
  kdeTheme = pkgs.catppuccin-kde.override {
    flavour = [flavor "latte"];
    accents = [accent];
  };
  papirusFolders = pkgs.catppuccin-papirus-folders.override {
    inherit flavor accent;
  };
  gtkTheme = pkgs.catppuccin-gtk.override {
    variant = flavor;
    accents = [accent];
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
      library = "org.kde.klassy";
    };
    plasmarc.Theme.name = "default";
  };

  ini = pkgs.formats.ini {};

  # Plasma Login Manager's greeter reads kscreenlockerrc's nested
  # [Greeter][Wallpaper][org.kde.image][General] group, which pkgs.formats.ini
  # can only express as one section whose name embeds the KDE group nesting;
  # the default ini generator escapes brackets, so section names pass through
  # literally here instead.
  loginIni = pkgs.formats.ini {mkSectionName = name: name;};
  loginKscreenlockerrc =
    kdeSettings.kscreenlockerrc
    // {
      "Greeter][Wallpaper][org.kde.image][General".Image = "file://${wallpaperImage}";
    };

  accountsServiceUser = ini.generate "zekurio-accountsservice" {
    User = {
      Icon = "/var/lib/AccountsService/icons/zekurio";
      SystemAccount = false;
    };
  };
in {
  catppuccin = {
    cursors = {
      enable = true;
      inherit accent flavor;
    };
    gtk.icon = {
      enable = true;
      inherit accent flavor;
    };
  };

  environment = {
    systemPackages = [
      kdeTheme
      papirusFolders
      pkgs.catppuccin-kvantum
      gtkTheme
    ];

    # Plasma Login Manager runs as the plasmalogin user and reads KConfig from
    # the system XDG config dirs before any user-specific files exist.
    etc = {
      "xdg/kdeglobals".source = ini.generate "catppuccin-kdeglobals" kdeSettings.kdeglobals;
      "xdg/kcminputrc".source = ini.generate "catppuccin-kcminputrc" kdeSettings.kcminputrc;
      "xdg/kscreenlockerrc".source = loginIni.generate "catppuccin-kscreenlockerrc" loginKscreenlockerrc;
      "xdg/ksplashrc".source = ini.generate "catppuccin-ksplashrc" kdeSettings.ksplashrc;
      "xdg/kwinrc".source = ini.generate "catppuccin-kwinrc" kdeSettings.kwinrc;
      "xdg/plasmarc".source = ini.generate "catppuccin-plasmarc" kdeSettings.plasmarc;
    };
  };

  # User avatar shown on the login/lock screen, read by AccountsService.
  systemd.tmpfiles.rules = [
    "L+ /var/lib/AccountsService/icons/zekurio - - - - ${faceImage}"
    "L+ /var/lib/AccountsService/users/zekurio - - - - ${accountsServiceUser}"
  ];

  home-manager.users.zekurio = {
    imports = [inputs.plasma-manager.homeModules.plasma-manager];

    home.pointerCursor.enable = true;

    programs.plasma.workspace.wallpaper = wallpaperImage;

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
      theme = {
        name = "catppuccin-${flavor}-${accent}-standard";
        package = gtkTheme;
      };
      gtk4.theme = {
        name = "catppuccin-${flavor}-${accent}-standard";
        package = gtkTheme;
      };
    };

    qt = {
      enable = true;
      platformTheme.name = "kde";
      style.name = "kvantum";
      kde.settings = lib.recursiveUpdate kdeSettings {
        kscreenlockerrc.Greeter.Wallpaper."org.kde.image".General.Image = "file://${wallpaperImage}";
      };
    };
  };
}
