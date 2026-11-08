{
  # With variable-refresh-rate on-demand=true on the output, which DMS's
  # display settings write to dms/outputs.kdl, niri only turns VRR on while
  # a window matching this rule is on screen. The desktop stays at a fixed
  # refresh rate, where VRR can flicker. Steam names its games steam_app_*.
  modules.niri.extraConfig = ''
    window-rule {
        match app-id=r#"^steam_app_"#
        match app-id=r#"^gamescope$"#
        variable-refresh-rate true
    }
  '';
}
