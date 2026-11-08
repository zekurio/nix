{
  # Dux writes this family to ~/.config/zed/themes on every theme change.
  # Zed reloads it there and follows the appearance Dux sets for the portal.
  home-manager.users.zekurio.programs.zed-editor.userSettings.theme = {
    mode = "system";
    light = "DankShell Light";
    dark = "DankShell Dark";
  };
}
