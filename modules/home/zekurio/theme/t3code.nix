{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (config.theme) hex mix white;
  inherit (config.theme.variants) dark light;

  colors = variant: let
    inherit (variant) shade accent base raised surface text dimText bright ansi brightAnsi;
  in
    lib.mapAttrs (_: hex) {
      chrome = base;
      toolbar = base;
      toolbarForeground = text;
      toolbarBorder = shade 46;
      toolbarControl = surface;
      toolbarControlForeground = text;
      toolbarControlHover = shade 54;
      surface = shade 31;
      surfaceRaised = raised;
      surfaceOverlay = surface;
      inherit text;
      textMuted = dimText;
      border = shade 46;
      input = shade 58;
      accentForeground = white;
      secondary = surface;
      secondaryForeground = text;
      muted = shade 31;
      mutedForeground = dimText;
      placeholder = brightAnsi.black;
      secondaryLabel = dimText;
      iconMuted = dimText;
      messageSurface = surface;
      messageForeground = text;
      messageAction = accent;
      messageActionForeground = white;
      messageActionHover = mix accent bright 15;
      codeBackground = shade 31;
      codeForeground = text;
      searchMatchBackground = mix base ansi.yellow 33;
      searchMatchForeground = text;
      searchMatchActiveBackground = mix base accent 40;
      searchMatchActiveForeground = bright;
      sidebar = raised;
      sidebarForeground = text;
      sidebarMutedForeground = dimText;
      sidebarControlSurface = surface;
      sidebarRowHover = surface;
      sidebarRowActive = shade 54;
      sidebarRowSelected = shade 54;
      sidebarBorder = shade 46;
      terminalBackground = base;
      terminalForeground = text;
      terminalCursor = accent;
      terminalSelection = variant.selection;
      terminalScrollbar = shade 58;
      terminalScrollbarHover = shade 88;
    };

  # T3 Code derives every role from the canvas and accent seeds, then layers
  # `colors` on top. The derivation tints all surfaces with the accent hue,
  # so the neutral greys are pinned here.
  themeFile = (pkgs.formats.json {}).generate "t3code-theme.json" {
    inherit (config.theme) name;
    inherit (dark) appearance;
    canvas = hex dark.base;
    accent = hex dark.accent;
    colors = colors dark;
    # A variant starts from T3 Code's stock palette instead of the seeds, so
    # it also sets the roles the seeds would have derived.
    variants.${light.appearance} =
      colors light
      // lib.mapAttrs (_: hex) {
        canvas = light.base;
        inherit (light) accent;
        focus = light.accent;
        update = light.accent;
        accentSurface = mix light.base light.accent 10;
        accentSurfaceForeground = light.text;
        updateSurface = mix light.base light.accent 10;
        updateForeground = light.text;
      };
  };
in {
  # The T3 Code server publishes <stateDir>/themes/<id>.json to its clients,
  # on the desktop app and on adam's remote server alike. It refuses to read
  # a symlinked file, so copy the file instead of linking it with home.file.
  home.activation.t3codeTheme = lib.hm.dag.entryAfter ["writeBoundary"] ''
    run install -Dm644 ${themeFile} \
      "$HOME/.t3/userdata/themes/${lib.toLower config.theme.name}.json"
  '';
}
