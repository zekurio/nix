{pkgs, ...}: let
  plasmaFont = {
    family = "IBM Plex Sans";
    pointSize = 10;
  };
  fixedWidthFont = {
    family = "BlexMono Nerd Font Mono";
    pointSize = 10;
  };
in {
  programs.plasma = {
    enable = true;

    fonts = {
      general = plasmaFont;
      menu = plasmaFont;
      toolbar = plasmaFont;
      windowTitle = plasmaFont;
      small = {
        family = plasmaFont.family;
        pointSize = 8;
      };
      fixedWidth = fixedWidthFont;
    };

    workspace = {
      windowDecorations = {
        library = "org.kde.klassy";
        theme = "Klassy";
      };
    };

    kwin.titlebarButtons.right = [
      "help"
      "minimize"
      "maximize"
      "close"
    ];

    configFile = {
      "klassy/klassyrc" = {
        ButtonBehaviour = {
          ShowCloseOutlineOnHoverActive = false;
          ShowCloseOutlineOnHoverInactive = false;
          ShowCloseOutlineOnPressActive = false;
          ShowCloseOutlineOnPressInactive = false;
          ShowOutlineOnHoverActive = false;
          ShowOutlineOnHoverInactive = false;
          ShowOutlineOnPressActive = false;
          ShowOutlineOnPressInactive = false;
        };
        ButtonColors = {
          ButtonBackgroundColorsActive = "TitleBarTextNegativeClose";
          ButtonBackgroundColorsInactive = "TitleBarTextNegativeClose";
          ButtonBackgroundOpacityActive = 13;
          ButtonBackgroundOpacityInactive = 13;
          ButtonOverrideColorsActiveClose = "{\"BackgroundHover\":[\"NegativeFullySaturated\"],\"BackgroundPress\":[\"NegativeFullySaturated\",60]}";
          ButtonOverrideColorsInactiveClose = "{\"BackgroundHover\":[\"NegativeFullySaturated\"],\"BackgroundPress\":[\"NegativeFullySaturated\",60]}";
          OnPoorIconContrastActive = "Nothing";
          OnPoorIconContrastInactive = "Nothing";
        };
        ButtonSizing = {
          ButtonCustomCornerRadius = 1;
          FullHeightButtonSpacingRight = 2;
          FullHeightButtonWidthMarginLeft = 8;
          FullHeightButtonWidthMarginRight = 24;
          IntegratedRoundedRectangleBottomPadding = 2;
          LockFullHeightButtonSpacingLeftRight = true;
        };
        Global = {
          LookAndFeelSet = "org.kde.breezedark.desktop";
          RefreshedConfig = "6.5.3";
        };
        TitleBarSpacing = {
          PercentMaximizedTopBottomMargins = 50;
          TitleAlignment = "AlignLeft";
          TitleBarBottomMargin = 4.5;
          TitleBarTopMargin = 4.5;
        };
        Windeco = {
          BoldButtonIcons = "BoldIconsFine";
          BoldTitle = false;
          ButtonIconStyle = "StyleMetro";
          ColorizeWindowOutlineWithButton = false;
          DrawTitleBarSeparator = false;
          IconSize = "IconMedium";
          MatchTitleBarToApplicationColor = true;
          RoundAllCornersWhenNoBorders = false;
          WindowCornerRadius = 0;
        };
        WindowOutlineStyle = {
          LockWindowOutlineStyleActiveInactive = true;
          WindowOutlineContrastOpacityActive = 50;
          WindowOutlineOverlap = false;
          WindowOutlineStyleActive = "WindowOutlineContrast";
          WindowOutlineStyleInactive = "WindowOutlineContrast";
        };
      };
    };
  };

  gtk = {
    enable = true;
    font = {
      name = plasmaFont.family;
      size = plasmaFont.pointSize;
    };
    theme = {
      name = "Breeze";
      package = pkgs.kdePackages.breeze-gtk;
    };
    gtk4.theme = {
      name = "Breeze";
      package = pkgs.kdePackages.breeze-gtk;
    };
    iconTheme = {
      name = "breeze-dark";
      package = pkgs.kdePackages.breeze-icons;
    };
    cursorTheme = {
      name = "breeze_cursors";
      package = pkgs.kdePackages.breeze;
      size = 24;
    };
    colorScheme = "dark";
  };
}
