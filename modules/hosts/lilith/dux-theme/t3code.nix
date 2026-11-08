{
  home-manager.users.zekurio = {
    config,
    lib,
    pkgs,
    ...
  }: let
    inherit (config.dux.colors.variants) dark light;

    colors = variant: let
      inherit (variant) accent onAccent accentContainer onAccentContainer selection highlight onHighlight base raised surface strong sidebar text dimText faintText border;
    in
      lib.mapAttrs (_: color: color.hex) {
        chrome = base;
        toolbar = base;
        toolbarForeground = text;
        toolbarBorder = border;
        toolbarControl = surface;
        toolbarControlForeground = text;
        toolbarControlHover = strong;
        surface = sidebar;
        surfaceRaised = raised;
        surfaceOverlay = surface;
        inherit text;
        textMuted = dimText;
        inherit border;
        input = strong;
        accentForeground = onAccent;
        secondary = surface;
        secondaryForeground = text;
        muted = sidebar;
        mutedForeground = dimText;
        placeholder = faintText;
        secondaryLabel = dimText;
        iconMuted = dimText;
        messageSurface = surface;
        messageForeground = text;
        messageAction = accent;
        messageActionForeground = onAccent;
        messageActionHover = accentContainer;
        codeBackground = sidebar;
        codeForeground = text;
        searchMatchBackground = highlight;
        searchMatchForeground = onHighlight;
        searchMatchActiveBackground = accentContainer;
        searchMatchActiveForeground = onAccentContainer;
        sidebar = raised;
        sidebarForeground = text;
        sidebarMutedForeground = dimText;
        sidebarControlSurface = surface;
        sidebarRowHover = surface;
        sidebarRowActive = strong;
        sidebarRowSelected = strong;
        sidebarBorder = border;
        terminalBackground = base;
        terminalForeground = text;
        terminalCursor = accent;
        terminalSelection = selection;
        terminalScrollbar = strong;
        terminalScrollbarHover = faintText;
      };
  in {
    # T3 Code derives every role from the canvas and accent seeds, then
    # layers `colors` on top. The derivation tints all surfaces with the
    # accent hue, so the surfaces are pinned to Dux's roles here. The server
    # publishes <stateDir>/themes/<id>.json to its clients and refuses to
    # read a symlinked file, which matugen's regular file avoids.
    dux.templates.t3code = {
      source = (pkgs.formats.json {}).generate "t3code-dux.json" {
        name = "Dux";
        appearance = dark.mode;
        canvas = dark.base.hex;
        accent = dark.accent.hex;
        colors = colors dark;
        # A variant starts from T3 Code's stock palette instead of the
        # seeds, so it also sets the roles the seeds would have derived.
        variants.${light.mode} =
          colors light
          // lib.mapAttrs (_: color: color.hex) {
            canvas = light.base;
            inherit (light) accent;
            focus = light.accent;
            update = light.accent;
            accentSurface = light.accentContainer;
            accentSurfaceForeground = light.onAccentContainer;
            updateSurface = light.accentContainer;
            updateForeground = light.onAccentContainer;
          };
      };
      target = "${config.home.homeDirectory}/.t3/userdata/themes/dux.json";
    };
  };
}
