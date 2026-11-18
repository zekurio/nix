{
  # DMS binds its screenshots to Print, which 75% keyboards such as the
  # EVO 75 lack. These mirror Windows' Win+Shift+S. They take over DMS's
  # Mod+Shift+S and Mod+Ctrl+S, which move windows to and from the
  # scratchpad; Mod+S still shows it.
  modules.hyprland.extraConfig = ''
    hl.unbind("SUPER + SHIFT + S")
    hl.unbind("SUPER + CTRL + S")
    hl.unbind("SUPER + ALT + S")
    hl.bind("SUPER + SHIFT + S", hl.dsp.exec_cmd("dms screenshot"), { description = "Screenshot: Region" })
    hl.bind("SUPER + CTRL + S", hl.dsp.exec_cmd("dms screenshot full"), { description = "Screenshot: Full Screen" })
    hl.bind("SUPER + ALT + S", hl.dsp.exec_cmd("dms screenshot window"), { description = "Screenshot: Window" })
  '';
}
