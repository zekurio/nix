{
  home-manager.users.zekurio = {
    config,
    lib,
    pkgs,
    ...
  }: let
    inherit (config.dux.colors) alpha variants;

    # Feishin builds a ten-shade palette around the theme's primary and paints
    # with the shade that mantineOverride.primaryShade names, 6 by default.
    # Its generator keeps primary itself only at the step whose HSL lightness
    # is closest to primary's. That step moves with the hue, from 1 to 4 in
    # dark mode and 6 to 9 in light mode, so the template writes primary's
    # lightness and this hook replaces it with the step, after matugen
    # renders. The ramp is Feishin 1.17's generator.
    primaryShade =
      lib.warnIf (pkgs.feishin.version != "1.17.0")
      "Feishin is past 1.17.0. Check its primary shade ramp against primaryShade in modules/hosts/lilith/dux-theme/feishin.nix."
      pkgs.writeShellApplication {
        name = "feishin-primary-shade";
        runtimeInputs = [pkgs.coreutils pkgs.jq];
        text = ''
          tmp=$(mktemp "$1.XXXXXX")
          jq '.mantineOverride.primaryShade |= map_values((tonumber / 100) as $l
            | [0.96, 0.907, 0.805, 0.697, 0.605, 0.547, 0.518, 0.445, 0.395, 0.34]
            | to_entries
            | min_by(.value - $l | if . < 0 then -. else . end)
            | .key)' "$1" > "$tmp"
          mv "$tmp" "$1"
        '';
      };

    theme = variant: let
      inherit (variant) accent base raised surface text dimText error ansi;
    in {
      inherit (variant) mode;
      colors = lib.mapAttrs (_: color: color.hex) {
        background = base;
        # Sidebars.
        background-alternate = raised;
        inherit surface;
        foreground = text;
        foreground-muted = dimText;
        surface-foreground = text;
        primary = accent;
        state-error = error;
        state-info = ansi.blue;
        state-success = ansi.green;
        state-warning = ansi.yellow;
      };
      # The hook above turns this into a palette index.
      mantineOverride.primaryShade.${variant.mode} = accent.lightness;
      # The default header overlays fade album art to black.
      app = lib.optionalAttrs (variant.mode == "light") {
        overlay-header = "linear-gradient(${alpha base 50} 0%, ${alpha base 80}), var(--theme-background-noise)";
        overlay-subheader = "linear-gradient(180deg, ${alpha base 5} 0%, var(--theme-colors-background)), var(--theme-background-noise)";
      };
    };
  in {
    # Feishin lists every JSON file in its themes folder and labels it after
    # the file name, so dux-light.json shows up as "Dux Light". Pick both
    # under Settings > Theme with "Follow system theme" on, and turn on "Use
    # theme accent color" and "Use theme primary shade"; Feishin keeps those
    # choices in local storage.
    dux.templates = lib.mapAttrs' (mode: variant: let
      id =
        if mode == "dark"
        then "dux"
        else "dux-${mode}";
      target = "${config.xdg.configHome}/feishin/Themes/${id}.json";
    in
      lib.nameValuePair "feishin-${mode}" {
        source = (pkgs.formats.json {}).generate "feishin-${id}.json" (theme variant);
        inherit target;
        postHook = "${lib.getExe primaryShade} ${lib.escapeShellArg target}";
      })
    variants;
  };
}
