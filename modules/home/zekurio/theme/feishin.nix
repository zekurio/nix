{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (config.theme) hex rgb variants;

  # Feishin lists every JSON file in its themes folder and labels it after
  # the file name, so lilith-light.json shows up as "Lilith Light".
  themesDir =
    if pkgs.stdenv.hostPlatform.isDarwin
    then "Library/Application Support/feishin/Themes"
    else ".config/feishin/Themes";

  theme = variant: let
    inherit (variant) accent base raised surface text dimText ansi;
  in {
    mode = variant.appearance;
    colors = lib.mapAttrs (_: hex) {
      background = base;
      # Sidebars.
      background-alternate = raised;
      inherit surface;
      foreground = text;
      foreground-muted = dimText;
      surface-foreground = text;
      primary = accent;
      state-error = ansi.red;
      state-info = ansi.blue;
      state-success = ansi.green;
      state-warning = ansi.yellow;
    };
    # The default header overlays fade album art to black.
    app = lib.optionalAttrs (variant.appearance == "light") {
      overlay-header = "linear-gradient(rgba(${rgb base}, 50%) 0%, rgba(${rgb base}, 80%)), var(--theme-background-noise)";
      overlay-subheader = "linear-gradient(180deg, rgba(${rgb base}, 5%) 0%, var(--theme-colors-background)), var(--theme-background-noise)";
    };
  };
in {
  # Pick both under Settings > Theme with "Follow system theme" on, and turn
  # on "Use theme accent color"; Feishin keeps those choices in local storage.
  home.file = lib.mapAttrs' (_: variant:
    lib.nameValuePair "${themesDir}/${variant.id}.json" {
      source = (pkgs.formats.json {}).generate "feishin-${variant.id}.json" (theme variant);
    })
  variants;
}
