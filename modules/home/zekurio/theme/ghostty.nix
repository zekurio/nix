{
  config,
  lib,
  ...
}: let
  inherit (config.theme) hex mix white ansiNames;
  # The SSH tint only picks dark backgrounds, so Ghostty stays dark.
  inherit (config.theme.variants) dark;
in {
  programs.ghostty = {
    settings.theme = dark.id;
    themes.${dark.id} = {
      # The SSH tint's OSC 111 resets to this background on disconnect.
      background = hex dark.base;
      foreground = hex dark.text;
      cursor-color = hex dark.accent;
      cursor-text = hex white;
      # The full accent is too loud across whole selected lines.
      selection-background = hex dark.selection;
      selection-foreground = hex dark.bright;
      palette =
        lib.imap0 (index: name: "${toString index}=${hex dark.ansi.${name}}") ansiNames
        ++ lib.imap0 (index: name: "${toString (index + 8)}=${hex dark.brightAnsi.${name}}") ansiNames;
    };
  };
}
