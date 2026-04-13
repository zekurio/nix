{
  interfaceResolution,
  resolution,
}: {
  enable = true;
  maxGenerations = 3;
  inherit resolution;
  secureBoot.enable = true;
  style = {
    interface = {
      resolution = interfaceResolution;
      brandingColor = 6; # OneDark cyan
    };
    wallpapers = [../../../../assets/ublue.png];
    backdrop = "282c34";
    graphicalTerminal = {
      background = "FF282c34";
      foreground = "abb2bf";
      brightForeground = "abb2bf";
      brightBackground = "3e4452";
      palette = "282c34;e06c75;98c379;d19a66;61afef;c678dd;56b6c2;5c6370";
      brightPalette = "3e4452;e06c75;98c379;e5c07b;61afef;c678dd;56b6c2;abb2bf";
      margin = 0;
      marginGradient = 0;
    };
  };
  extraConfig = ''
    remember_last_entry: yes
  '';
}
