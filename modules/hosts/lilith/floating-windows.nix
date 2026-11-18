{
  # Utility windows that open floating instead of tiled. Electron and Qt apps
  # report their desktop file name as the class on Wayland and their window
  # class under Xwayland, so each match accepts both. Steam's games use
  # steam_app_* classes and stay tiled. Static rules only see the title a
  # window opens with, and the last match wins, so Big Picture's own rule
  # comes after Steam's.
  modules.hyprland.extraConfig = ''
    hl.window_rule({ match = { class = [[(?i)^(1password|com\.onepassword\.onepassword)$]] }, float = true })
    hl.window_rule({ match = { class = [[^steam$]] }, float = true })
    hl.window_rule({ match = { class = [[^steam$]], title = [[^Steam Big Picture Mode$]] }, tile = true })
    hl.window_rule({ match = { class = [[(?i)^(org\.coolercontrol\.)?coolercontrol$]] }, float = true })
    hl.window_rule({ match = { class = [[(?i)^(org\.openrgb\.)?openrgb$]] }, float = true })
  '';
}
