{
  config,
  lib,
  ...
}: let
  inherit (config.theme) hex white ansiNames variants;
  ghosttyTheme = variant: {
    # The SSH tint's OSC 111 resets to this background on disconnect.
    background = hex variant.base;
    foreground = hex variant.text;
    cursor-color = hex variant.accent;
    cursor-text = hex white;
    # The full accent is too loud across whole selected lines.
    selection-background = hex variant.selection;
    selection-foreground = hex variant.bright;
    palette =
      lib.imap0 (index: name: "${toString index}=${hex variant.ansi.${name}}") ansiNames
      ++ lib.imap0 (index: name: "${toString (index + 8)}=${hex variant.brightAnsi.${name}}") ansiNames;
  };
in {
  programs.ghostty = {
    # Ghostty picks the theme from the system appearance and reports it to the
    # SSH tint, which then chooses a matching background.
    settings.theme = "light:${variants.light.id},dark:${variants.dark.id}";
    themes = lib.mapAttrs' (_: variant: lib.nameValuePair variant.id (ghosttyTheme variant)) variants;
  };
}
