{
  # Hyprland stops sending frame callbacks to windows on hidden workspaces.
  # Under winewayland (PROTON_ENABLE_WAYLAND=1) a game's FIFO present then
  # blocks until it is shown again, and games such as Cyberpunk 2077 crash
  # or drop their server connection a few seconds after a workspace switch.
  # render_unfocused keeps the callbacks coming at misc.render_unfocused_fps,
  # 15 by default. Proton sets steam_app_<SteamAppId> as the app ID on
  # Wayland too, so this matches the same classes as game-vrr.nix.
  modules.hyprland.extraConfig = ''
    hl.window_rule({ match = { class = [[^(steam_app_.*|gamescope)$]] }, render_unfocused = true })
  '';
}
