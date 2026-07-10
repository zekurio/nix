{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (config.catppuccin) accent flavor;

  accentTitle = lib.toSentenceCase accent;
  wallpaperDirectory = ../../../../assets/wallpapers;
  wallpaperFiles = builtins.attrNames (builtins.readDir wallpaperDirectory);
  wallpaperBasename = filename:
    lib.removeSuffix ".jpeg" (lib.removeSuffix ".jpg" (lib.removeSuffix ".png" filename));
  wallpaperId = filename: "zekurio.${wallpaperBasename filename}";
  wallpaperTitle = filename: lib.toSentenceCase (lib.replaceStrings ["-"] [" "] (wallpaperBasename filename));
  mkWallpaperMetadata = filename:
    pkgs.writeText "${wallpaperBasename filename}-wallpaper-metadata.json" (builtins.toJSON {
      KPlugin = {
        Authors = [{Name = "Zekurio";}];
        Id = wallpaperId filename;
        License = "LicenseRef-Proprietary";
        Name = wallpaperTitle filename;
      };
    });
  faceImage = ../../../../assets/face.png;

  # Keep the Catppuccin package as a source for its color schemes, but do not
  # install its global themes: they select Catppuccin cursors and Aurorae
  # decorations instead of the Breeze/Klassy combination used here.
  catppuccinKde = pkgs.catppuccin-kde.override {
    flavour = [flavor "latte"];
    accents = [accent];
  };
  papirusFolders = pkgs.catppuccin-papirus-folders.override {
    inherit accent flavor;
  };

  mkDesign = {
    flavor,
    iconTheme,
  }: let
    flavorTitle = lib.toSentenceCase flavor;
    id = "local.custom.catppuccin-${flavor}.desktop";
  in {
    inherit id;
    defaults = pkgs.writeText "${id}-defaults" ''
      [kdeglobals][KDE]
      widgetStyle=Breeze

      [kdeglobals][General]
      ColorScheme=Catppuccin${flavorTitle}${accentTitle}

      [kdeglobals][Icons]
      Theme=${iconTheme}

      [plasmarc][Theme]
      name=default

      [Wallpaper]
      Image=${wallpaperId "gits.jpeg"}

      [kcminputrc][Mouse]
      cursorTheme=breeze_cursors

      [kwinrc][org.kde.kdecoration2]
      library=org.kde.klassy
      theme=Klassy

      [kscreenlockerrc][Greeter]
      LnFPackage=org.kde.breeze.desktop

      [ksplashrc][KSplash]
      Theme=org.kde.breeze.desktop
    '';
    metadata = pkgs.writeText "${id}-metadata.json" (builtins.toJSON {
      KPackageStructure = "Plasma/LookAndFeel";
      KPlugin = {
        Authors = [{Name = "Custom";}];
        Category = "Global Themes (Plasma 6)";
        Description = "Catppuccin ${flavorTitle} colors with Breeze and Klassy";
        EnabledByDefault = true;
        Id = id;
        License = "LicenseRef-Proprietary";
        Name = "Custom ${flavorTitle}";
      };
      "X-Plasma-APIVersion" = "2";
    });
  };

  designs = [
    (mkDesign {
      inherit flavor;
      iconTheme = "Papirus-Dark";
    })
    (mkDesign {
      flavor = "latte";
      iconTheme = "Papirus-Light";
    })
  ];

  plasmaDesigns =
    pkgs.runCommand "custom-plasma-designs" {
      nativeBuildInputs = [pkgs.imagemagick];
    } ''
      mkdir -p "$out/share"
      cp -r ${catppuccinKde}/share/color-schemes "$out/share/"

      ${lib.concatMapStringsSep "\n" (filename: let
          extension = lib.last (lib.splitString "." filename);
          wallpaper = "$out/share/wallpapers/${wallpaperId filename}";
        in ''
          install -Dm644 ${wallpaperDirectory + "/${filename}"} "${wallpaper}/contents/images/1920x1080.${extension}"
          install -Dm644 ${mkWallpaperMetadata filename} "${wallpaper}/metadata.json"
        '')
        wallpaperFiles}

      ${lib.concatMapStringsSep "\n" (design: ''
          theme="$out/share/plasma/look-and-feel/${design.id}"
          install -Dm644 ${design.defaults} "$theme/contents/defaults"
          install -Dm644 ${design.metadata} "$theme/metadata.json"
          install -Dm644 ${wallpaperDirectory + "/gits.jpeg"} "$theme/contents/previews/fullscreenpreview.jpg"
          magick ${wallpaperDirectory + "/gits.jpeg"} -thumbnail 400x225^ -gravity center -extent 400x225 "$theme/contents/previews/preview.png"
          install -Dm644 ${pkgs.writeText "${design.id}-layout.js" ''
            var desktopsArray = desktopsForActivity(currentActivity());
            for (var i = 0; i < desktopsArray.length; i++) {
                desktopsArray[i].wallpaperPlugin = "org.kde.image";
            }
          ''} "$theme/contents/layouts/org.kde.plasma.desktop-layout.js"
        '')
        designs}
    '';

  ini = pkgs.formats.ini {};
  accountsServiceUser = ini.generate "zekurio-accountsservice" {
    User = {
      Icon = "/var/lib/AccountsService/icons/zekurio";
      SystemAccount = false;
    };
  };
in {
  environment.systemPackages = [
    papirusFolders
    plasmaDesigns
  ];

  # User avatar shown on the login/lock screen, read by AccountsService.
  systemd.tmpfiles.rules = [
    "L+ /var/lib/AccountsService/icons/zekurio - - - - ${faceImage}"
    "L+ /var/lib/AccountsService/users/zekurio - - - - ${accountsServiceUser}"
  ];

  home-manager.users.zekurio = {
    # Re-assert the dark design on every login so a fresh install (or a
    # detour through System Settings) always lands back on the intended
    # look. Switching to Custom Latte by hand still works within a session
    # but won't survive a re-login; drop this line if that ever bothers you.
    programs.plasma.workspace.lookAndFeel = (builtins.head designs).id;

    # Breeze GTK follows Plasma's selected color scheme, allowing the Latte and
    # Frappé global themes to switch light/dark application colors together.
    gtk = {
      enable = true;
      theme = {
        name = "Breeze";
        package = pkgs.kdePackages.breeze-gtk;
      };
      gtk4.theme = {
        name = "Breeze";
        package = pkgs.kdePackages.breeze-gtk;
      };
    };

    qt = {
      enable = true;
      platformTheme.name = "kde";
    };
  };
}
