{
  # Utility windows that open floating instead of taking a column. Electron
  # and Qt apps report their desktop file name on Wayland and their window
  # class under Xwayland, so each match accepts both. Steam's games use
  # steam_app_* IDs and stay tiled; Big Picture keeps the full screen.
  modules.niri.extraConfig = ''
    window-rule {
        match app-id=r#"(?i)^(1password|com\.onepassword\.onepassword)$"#
        match app-id=r#"^steam$"#
        match app-id=r#"(?i)^(org\.coolercontrol\.)?coolercontrol$"#
        match app-id=r#"(?i)^(org\.openrgb\.)?openrgb$"#
        exclude app-id=r#"^steam$"# title=r#"^Steam Big Picture Mode$"#
        open-floating true
    }
  '';
}
