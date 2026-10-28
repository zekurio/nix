{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (config.home-manager.users.zekurio.theme) rgb grey mix white variants;

  negative = [218 68 83];
  neutral = [246 116 0];
  positive = [39 174 96];

  # Like BreezeLight.colors, the file name drops the space that Name keeps.
  schemeName = variant: lib.replaceStrings [" "] [""] variant.name;

  colors = variant: let
    inherit (variant) shade accent base raised surface text dimText brightAnsi;
    visited = mix accent dimText 50;

    colorSet = background: alternate: {
      BackgroundNormal = background;
      BackgroundAlternate = alternate;
      ForegroundNormal = text;
      ForegroundInactive = dimText;
      ForegroundActive = accent;
      ForegroundLink = brightAnsi.red;
      ForegroundVisited = visited;
      ForegroundNegative = negative;
      ForegroundNeutral = neutral;
      ForegroundPositive = positive;
      DecorationFocus = accent;
      DecorationHover = accent;
    };
  in {
    "Colors:View" = colorSet base (shade 31);
    "Colors:Window" = colorSet raised surface;
    "Colors:Button" = colorSet surface (mix surface accent 30);
    "Colors:Header" = colorSet surface raised;
    # KConfig nests groups as [Colors:Header][Inactive]. Plasma copies the
    # window colours into inactive headers only when this group exists.
    "Colors:Header][Inactive" = colorSet raised surface;
    "Colors:Tooltip" = colorSet surface raised;
    "Colors:Complementary" = colorSet raised (mix raised accent 30);
    "Colors:Selection" =
      colorSet accent (mix accent (grey 0) 25)
      // {
        ForegroundNormal = white;
        ForegroundInactive = mix white accent 30;
        ForegroundActive = white;
        ForegroundLink = [253 188 75];
        # The semantic colours are too dark to read on the accent.
        ForegroundVisited = mix visited white 60;
        ForegroundNegative = mix negative white 60;
        ForegroundNeutral = mix neutral white 60;
        ForegroundPositive = mix positive white 60;
      };
    WM = {
      activeBackground = surface;
      activeBlend = text;
      activeForeground = text;
      inactiveBackground = raised;
      inactiveBlend = dimText;
      inactiveForeground = dimText;
    };
  };

  colorSchemePackage = variant:
    pkgs.writeTextDir "share/color-schemes/${schemeName variant}.colors" (
      # toINI would escape the brackets of the nested header group.
      lib.generators.toINI {mkSectionName = lib.id;} (
        lib.mapAttrs (_: lib.mapAttrs (_: rgb)) (colors variant)
        // {
          General = {
            ColorScheme = schemeName variant;
            Name = variant.name;
            shadeSortColumn = true;
          };
          KDE.contrast = 4;
          # Breeze and Breeze Light share these effects.
          "ColorEffects:Disabled" = {
            Color = rgb (grey 56);
            ColorAmount = 0;
            ColorEffect = 0;
            ContrastAmount = 0.65;
            ContrastEffect = 1;
            IntensityAmount = 0.1;
            IntensityEffect = 2;
          };
          "ColorEffects:Inactive" = {
            ChangeSelectionColor = true;
            Color = rgb (grey 112);
            ColorAmount = 0.025;
            ColorEffect = 2;
            ContrastAmount = 0.1;
            ContrastEffect = 2;
            Enable = false;
            IntensityAmount = 0;
            IntensityEffect = 0;
          };
        }
      )
    );
in {
  environment.systemPackages =
    map colorSchemePackage (lib.attrValues variants)
    ++ [
      pkgs.klassy
      # Papirus ships blue folders; red is its folder colour nearest the accent.
      (pkgs.papirus-icon-theme.override {color = "red";})
    ];

  # Plasma re-applies the scheme at login whenever this file's hash changes,
  # so palette edits need a new session, not a new scheme name. Lilith Light
  # is only installed: once picked under Colors, it stays until a change to
  # the workspace settings below re-runs plasma-manager's apply script.
  home-manager.users.zekurio.programs.plasma = {
    workspace = {
      colorScheme = schemeName variants.dark;
      # Papirus' symbolic icons take their colour from the scheme, so the
      # dark set also works under Lilith Light.
      iconTheme = "Papirus-Dark";
      windowDecorations = {
        library = "org.kde.klassy";
        theme = "Klassy";
      };
    };
    # A stored accent replaces the scheme's own, and Plasma keeps rewriting
    # it from the wallpaper while that option is on.
    configFile.kdeglobals.General = {
      AccentColor = null;
      accentColorFromWallpaper = false;
    };
  };
}
