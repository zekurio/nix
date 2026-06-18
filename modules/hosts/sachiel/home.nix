{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  system = pkgs.stdenv.hostPlatform.system;
  catppuccinGtk = pkgs.catppuccin-gtk.override {
    variant = "frappe";
    accents = ["blue"];
    size = "standard";
  };
  catppuccinKde = pkgs.catppuccin-kde.override {
    flavour = ["frappe"];
    accents = ["blue"];
    winDecStyles = ["modern"];
  };
  catppuccinKvantum = pkgs.catppuccin-kvantum.override {
    variant = "frappe";
    accent = "blue";
  };
  kwriteconfig = "${pkgs.kdePackages.kconfig}/bin/kwriteconfig6";
  fonts = {
    sans = "Fira Sans";
    mono = "FiraCode Nerd Font";
    serif = "Roboto Slab";
    emoji = "Noto Color Emoji";
  };
in {
  home = {
    packages = [
      inputs.helium.packages.${system}.default
      catppuccinKde
      catppuccinGtk
      catppuccinKvantum
      pkgs.feishin
    ];
    sessionVariables = {
      BROWSER = "helium";
      DEFAULT_BROWSER = "helium";
    };
    activation.configureKdeDesktop = lib.hm.dag.entryAfter ["writeBoundary"] ''
      ${kwriteconfig} --file kdeglobals --group General --key ColorScheme CatppuccinFrappeBlue
      ${kwriteconfig} --file kdeglobals --group General --key fixed "${fonts.mono},10,-1,5,50,0,0,0,0,0"
      ${kwriteconfig} --file kdeglobals --group General --key font "${fonts.sans},10,-1,5,50,0,0,0,0,0"
      ${kwriteconfig} --file kdeglobals --group General --key menuFont "${fonts.sans},10,-1,5,50,0,0,0,0,0"
      ${kwriteconfig} --file kdeglobals --group General --key Name CatppuccinFrappeBlue
      ${kwriteconfig} --file kdeglobals --group General --key smallestReadableFont "${fonts.sans},8,-1,5,50,0,0,0,0,0"
      ${kwriteconfig} --file kdeglobals --group General --key toolBarFont "${fonts.sans},10,-1,5,50,0,0,0,0,0"
      ${kwriteconfig} --file kdeglobals --group Icons --key Theme Papirus-Dark
      ${kwriteconfig} --file kdeglobals --group KDE --key LookAndFeelPackage Catppuccin-Frappe-Blue
      ${kwriteconfig} --file kcminputrc --group Mouse --key cursorTheme catppuccin-frappe-blue-cursors
      ${kwriteconfig} --file kwinrc --group org.kde.kdecoration2 --key library org.kde.klassy
      ${kwriteconfig} --file kwinrc --group org.kde.kdecoration2 --key theme Klassy
      ${kwriteconfig} --file plasmarc --group Theme --key name Catppuccin-Frappe-Blue
    '';
  };

  programs = {
    ghostty = {
      enable = true;
      settings = {
        font-family = fonts.mono;
        font-size = 12;
        window-padding-x = 8;
        window-padding-y = 8;
      };
    };
    zed-editor = {
      enable = true;
      package = inputs.zed.packages.${system}.default;
      defaultEditor = true;
      extensions = [
        "nix"
      ];
      userSettings = {
        telemetry = {
          diagnostics = false;
          metrics = false;
        };
        ui_font_family = fonts.sans;
        ui_font_size = 16;
        buffer_font_family = fonts.mono;
        buffer_font_size = 15;
      };
    };
    vesktop = {
      enable = true;
      vencord.useSystem = true;
      settings = {
        arRPC = true;
        checkUpdates = false;
        discordBranch = "stable";
        hardwareAcceleration = true;
        minimizeToTray = true;
        tray = true;
      };
    };
  };

  gtk = {
    enable = true;
    colorScheme = "dark";
    font = {
      name = fonts.sans;
      size = 10;
    };
    theme = {
      name = "catppuccin-frappe-blue-standard";
      package = catppuccinGtk;
    };
    gtk4.theme = config.gtk.theme;
  };

  qt = {
    enable = true;
    platformTheme.name = "kde";
    style = {
      name = "kvantum";
      package = catppuccinKvantum;
    };
  };

  fonts.fontconfig = {
    enable = lib.mkForce true;
    defaultFonts = {
      sansSerif = [fonts.sans];
      monospace = [fonts.mono];
      serif = [fonts.serif];
      emoji = [fonts.emoji];
    };
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html" = ["helium.desktop"];
      "x-scheme-handler/http" = ["helium.desktop"];
      "x-scheme-handler/https" = ["helium.desktop"];
    };
  };

  catppuccin = {
    enable = true;
    flavor = "frappe";
    accent = "blue";
    cursors = {
      enable = true;
      flavor = "frappe";
      accent = "blue";
    };
    gtk.icon.enable = true;
    ghostty.enable = true;
    kvantum = {
      enable = true;
      flavor = "frappe";
      accent = "blue";
    };
    vesktop = {
      enable = true;
      flavor = "frappe";
      accent = "blue";
    };
    zed = {
      enable = true;
      flavor = "frappe";
      accent = "blue";
      icons = {
        enable = true;
        flavor = "frappe";
      };
    };
  };
}
