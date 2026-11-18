{
  # Under Wine's Wayland driver, Forza Horizon 6 maps an empty, untitled
  # toplevel before its game window. Nothing ever draws into it, yet it keeps
  # taking focus back from the game. Static rules see the title a window maps
  # with, so the empty title only matches the stray window.
  #
  # Both windows map floating at 2560x1440, the game window partly
  # off-screen. Fullscreening it covers the stray window and is also what
  # monitors.nix needs for VRR and auto HDR.
  modules.hyprland.extraConfig = ''
    hl.window_rule({ match = { class = [[^steam_app_2483190$]], initial_title = [[^$]] }, no_initial_focus = true, no_focus = true, focus_on_activate = false, suppress_event = "activate activatefocus" })
    hl.window_rule({ match = { class = [[^steam_app_2483190$]], initial_title = [[^Forza Horizon 6$]] }, fullscreen = true })
  '';
}
