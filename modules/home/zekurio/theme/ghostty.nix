{
  config,
  lib,
  ...
}: let
  inherit (config.theme) hex mix accent base text white ansi brightAnsi ansiNames;
  themeName = lib.toLower config.theme.name;
in {
  programs.ghostty = {
    settings.theme = themeName;
    themes.${themeName} = {
      # The SSH tint's OSC 111 resets to this background on disconnect.
      background = hex base;
      foreground = hex text;
      cursor-color = hex accent;
      cursor-text = hex white;
      selection-background = hex (mix base accent 50);
      selection-foreground = hex white;
      palette =
        lib.imap0 (index: name: "${toString index}=${hex ansi.${name}}") ansiNames
        ++ lib.imap0 (index: name: "${toString (index + 8)}=${hex brightAnsi.${name}}") ansiNames;
    };
  };
}
