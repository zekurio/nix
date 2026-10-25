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

      # The only hue in the palette. White text on it keeps a 4.6:1 contrast.
      accent = [214 60 64];

      # Breeze Dark's lightness steps without its blue tint.
      base = grey 22;
      raised = grey 35;
      surface = grey 44;
      text = grey 240;
      dimText = grey 160;
      white = grey 255;

      # Terminal output and syntax highlighting need more hues to tell things
      # apart, so these share one lightness and a low chroma to stay quieter
      # than the red.
      ansi = {
        black = surface;
        red = mix accent white 15;
        green = [134 185 144];
        yellow = [194 167 111];
        blue = [137 174 221];
        magenta = [194 155 203];
        cyan = [105 186 191];
        white = grey 200;
      };
      brightAnsi = {
        black = grey 120;
        red = mix accent white 30;
        green = [162 215 172];
        yellow = [223 196 139];
        blue = [165 202 251];
        magenta = [223 183 232];
        cyan = [134 215 220];
        inherit white;
      };
    in {
      name = "Lilith";
      inherit rgb hex grey mix accent base raised surface text dimText white ansi brightAnsi;
      ansiNames = ["black" "red" "green" "yellow" "blue" "magenta" "cyan" "white"];
    };
  };
}
