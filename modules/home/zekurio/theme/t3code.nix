{
  flake.modules.homeManager.zekurio = {
    config,
    lib,
    pkgs,
    ...
  }: let
    inherit (config.theme) hex grey mix accent base raised surface text dimText white ansi;

    # T3 Code derives every role from the canvas and accent seeds, then layers
    # `colors` on top. The derivation tints all surfaces with the accent hue,
    # so the neutral greys are pinned here.
    themeFile = (pkgs.formats.json {}).generate "t3code-theme.json" {
      inherit (config.theme) name;
      appearance = "dark";
      canvas = hex base;
      accent = hex accent;
      colors = lib.mapAttrs (_: hex) {
        chrome = base;
        toolbar = base;
        toolbarForeground = text;
        toolbarBorder = grey 46;
        toolbarControl = surface;
        toolbarControlForeground = text;
        toolbarControlHover = grey 54;
        surface = grey 31;
        surfaceRaised = raised;
        surfaceOverlay = surface;
        inherit text;
        textMuted = dimText;
        border = grey 46;
        input = grey 58;
        accentForeground = white;
        secondary = surface;
        secondaryForeground = text;
        muted = grey 31;
        mutedForeground = dimText;
        placeholder = grey 120;
        secondaryLabel = dimText;
        iconMuted = dimText;
        messageSurface = surface;
        messageForeground = text;
        messageAction = accent;
        messageActionForeground = white;
        messageActionHover = ansi.red;
        codeBackground = grey 31;
        codeForeground = text;
        searchMatchBackground = mix base ansi.yellow 33;
        searchMatchForeground = text;
        searchMatchActiveBackground = mix base accent 40;
        searchMatchActiveForeground = white;
        sidebar = raised;
        sidebarForeground = text;
        sidebarMutedForeground = dimText;
        sidebarControlSurface = surface;
        sidebarRowHover = surface;
        sidebarRowActive = grey 54;
        sidebarRowSelected = grey 54;
        sidebarBorder = grey 46;
        terminalBackground = base;
        terminalForeground = text;
        terminalCursor = accent;
        terminalSelection = mix base accent 50;
        terminalScrollbar = grey 58;
        terminalScrollbarHover = grey 88;
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
  };
}
