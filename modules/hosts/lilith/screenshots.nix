{
  # DMS binds its screenshots to Print, which 75% keyboards such as the
  # EVO 75 lack. These mirror Windows' Win+Shift+S.
  modules.niri.extraConfig = ''
    binds {
        Mod+Shift+S hotkey-overlay-title="Screenshot: Region" { spawn "dms" "screenshot"; }
        Mod+Ctrl+S hotkey-overlay-title="Screenshot: Full Screen" { spawn "dms" "screenshot" "full"; }
        Mod+Alt+S hotkey-overlay-title="Screenshot: Window" { spawn "dms" "screenshot" "window"; }
    }
  '';
}
