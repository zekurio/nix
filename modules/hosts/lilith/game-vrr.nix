{
  # The monitor's vrr = 3 in monitors.nix only turns VRR on for fullscreen
  # windows whose content type is game or video. Few games set one, so this
  # marks them. The desktop stays at a fixed refresh rate, where VRR can
  # flicker. Steam names its games steam_app_*.
  modules.hyprland.extraConfig = ''
    hl.window_rule({ match = { class = [[^(steam_app_.*|gamescope)$]] }, content = "game" })
  '';
}
