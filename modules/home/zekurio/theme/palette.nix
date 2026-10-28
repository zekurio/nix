{lib, ...}: {
  # One palette for every themed app. NixOS hosts read it through
  # home-manager.users.zekurio.theme.
  options.theme = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    description = "Shared colour palette and helpers for app themes.";
    default = let
      # Colours are [r g b] lists so the shades below can be derived from them.
      rgb = lib.concatMapStringsSep "," toString;
      hex = color:
        "#" + lib.concatMapStrings (channel: lib.toLower (lib.fixedWidthString 2 "0" (lib.toHexString channel))) color;
      grey = level: [level level level];
      mix = from: to: percent:
        lib.zipListsWith (a: b: (a * (100 - percent) + b * percent) / 100) from to;
      white = grey 255;

      # Terminals print with black and white too, so derive them from each
      # variant's own greys: black near the canvas, white near the text.
      neutralAnsi = variant: {
        black = variant.surface;
        white = mix variant.text variant.dimText 50;
      };

      dark = rec {
        name = "Lilith";
        id = "lilith";
        appearance = "dark";

        # The only hue in the palette. White text on it keeps a 4.6:1 contrast.
        accent = [214 60 64];

        # Breeze Dark's lightness steps without its blue tint.
        base = grey 22;
        raised = grey 35;
        surface = grey 44;
        text = grey 240;
        dimText = grey 160;
        # The strongest text. White always stays the text on the accent.
        bright = white;
        selection = mix base accent 50;
        # Apps name their in-between greys by lightness on this dark ramp.
        shade = grey;

        # Terminal output and syntax highlighting need more hues to tell things
        # apart, so these share one lightness and a low chroma to stay quieter
        # than the red.
        ansi =
          neutralAnsi dark
          // {
            red = mix accent white 15;
            green = [134 185 144];
            yellow = [194 167 111];
            blue = [137 174 221];
            magenta = [194 155 203];
            cyan = [105 186 191];
          };
        brightAnsi = {
          black = grey 120;
          red = mix accent white 30;
          green = [162 215 172];
          yellow = [223 196 139];
          blue = [165 202 251];
          magenta = [223 183 232];
          cyan = [134 215 220];
          white = bright;
        };
      };

      # The canvas, text and hues of the Lilith preset in the wiki's
      # themes.css. Its hues are stronger than the dark ones because pale
      # colours wash out on a light canvas.
      light = rec {
        name = "Lilith Light";
        id = "lilith-light";
        appearance = "light";

        accent = [204 43 43];

        base = grey 245;
        raised = shade 35;
        surface = shade 44;
        text = grey 23;
        dimText = grey 82;
        bright = grey 0;
        selection = mix base accent 25;
        # Mirror the dark ramp between canvas and text, so a grey just above
        # the dark canvas lands just below the light one.
        shade = level: grey (245 - (level - 22) * 222 / 218);

        ansi =
          neutralAnsi light
          // {
            red = [202 43 43];
            green = [41 142 67];
            yellow = [179 140 25];
            blue = [43 109 202];
            magenta = [122 43 202];
            cyan = [30 143 143];
          };
        # Brighter means more contrast, which on a light canvas is darker.
        brightAnsi =
          lib.mapAttrs (_: color: mix color (grey 0) 20) ansi
          // {
            black = grey 107;
            white = bright;
          };
      };
    in {
      name = "Lilith";
      inherit rgb hex grey mix white;
      ansiNames = ["black" "red" "green" "yellow" "blue" "magenta" "cyan" "white"];
      variants = {inherit dark light;};
    };
  };
}
