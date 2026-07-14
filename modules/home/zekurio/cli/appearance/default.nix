{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (config.catppuccin) sources;

  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
  toml = pkgs.formats.toml {};
  starshipSettings = config.programs.starship.settings;
  starshipPalettes = {
    palettes = {
      catppuccin_latte = {
        rosewater = "#dc8a78";
        flamingo = "#dd7878";
        pink = "#ea76cb";
        mauve = "#8839ef";
        red = "#d20f39";
        maroon = "#e64553";
        peach = "#fe640b";
        yellow = "#df8e1d";
        green = "#40a02b";
        teal = "#179299";
        sky = "#04a5e5";
        sapphire = "#209fb5";
        blue = "#1e66f5";
        lavender = "#7287fd";
        text = "#4c4f69";
        subtext1 = "#5c5f77";
        subtext0 = "#6c6f85";
        overlay2 = "#7c7f93";
        overlay1 = "#8c8fa1";
        overlay0 = "#9ca0b0";
        surface2 = "#acb0be";
        surface1 = "#bcc0cc";
        surface0 = "#ccd0da";
        base = "#eff1f5";
        mantle = "#e6e9ef";
        crust = "#dce0e8";
      };
      catppuccin_frappe = {
        rosewater = "#f2d5cf";
        flamingo = "#eebebe";
        pink = "#f4b8e4";
        mauve = "#ca9ee6";
        red = "#e78284";
        maroon = "#ea999c";
        peach = "#ef9f76";
        yellow = "#e5c890";
        green = "#a6d189";
        teal = "#81c8be";
        sky = "#99d1db";
        sapphire = "#85c1dc";
        blue = "#8caaee";
        lavender = "#babbf1";
        text = "#c6d0f5";
        subtext1 = "#b5bfe2";
        subtext0 = "#a5adce";
        overlay2 = "#949cbb";
        overlay1 = "#838ba7";
        overlay0 = "#737994";
        surface2 = "#626880";
        surface1 = "#51576d";
        surface0 = "#414559";
        base = "#303446";
        mantle = "#292c3c";
        crust = "#232634";
      };
    };
  };
  mkStarshipConfig = flavor:
    toml.generate "starship-${flavor}.toml" (
      starshipSettings
      // {
        palette = "catppuccin_${flavor}";
      }
    );
in {
  # Ports that only accept one flavor are installed here in both variants.
  # Fish selects the matching immutable asset instead of rewriting managed files.
  catppuccin = {
    bat.enable = false;
    eza.enable = false;
    fish.enable = false;
    ghostty.enable = false;
    starship.enable = false;
  };

  programs = {
    bat = {
      themes = {
        "Catppuccin Latte" = {
          src = sources.bat;
          file = "Catppuccin Latte.tmTheme";
        };
        "Catppuccin Frappe" = {
          src = sources.bat;
          file = "Catppuccin Frappe.tmTheme";
        };
      };
    };

    fish.interactiveShellInit = ''
      function __catppuccin_sync_appearance --on-event fish_prompt
        set -l flavor frappe
        ${lib.optionalString isDarwin ''
        if not /usr/bin/defaults read -g AppleInterfaceStyle 2>/dev/null | string match -q Dark
          set flavor latte
        end
      ''}

        if test "$flavor" = "$__catppuccin_flavor"
          return
        end

        set -g __catppuccin_flavor $flavor
        fish_config theme choose catppuccin-$flavor >/dev/null
        set -gx EZA_CONFIG_DIR "$HOME/.config/eza/$flavor"
        set -gx STARSHIP_CONFIG "$HOME/.config/starship/$flavor.toml"

        if test "$flavor" = latte
          set -gx BAT_THEME "Catppuccin Latte"
        else
          set -gx BAT_THEME "Catppuccin Frappe"
        end
      end

      __catppuccin_sync_appearance
    '';

    starship.settings = starshipPalettes;
  };

  xdg.configFile = {
    "fish/themes/catppuccin-latte.theme".source = "${sources.fish}/static/catppuccin-latte.theme";
    "fish/themes/catppuccin-frappe.theme".source = "${sources.fish}/static/catppuccin-frappe.theme";

    "eza/latte/theme.yml".source = "${sources.eza}/latte/catppuccin-latte-blue.yml";
    "eza/frappe/theme.yml".source = "${sources.eza}/frappe/catppuccin-frappe-blue.yml";

    "starship/latte.toml".source = mkStarshipConfig "latte";
    "starship/frappe.toml".source = mkStarshipConfig "frappe";
  };
}
