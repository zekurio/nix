{
  # The ASUS XG27AQWMG's EDID advertises 10 bits per channel, BT.2020 and
  # SMPTE ST 2084, so Hyprland takes its luminance range from there.
  #
  # cm = "hdr" keeps the desktop in HDR, so windowed HDR video and games
  # work too. Hyprland maps SDR windows into it; DMS's display settings tune
  # that with SDR brightness and saturation. cm = "auto" would leave the
  # desktop in SDR and switch to HDR only for fullscreen HDR content, through
  # render.cm_auto_hdr.
  #
  # vrr = 3 turns VRR on only for fullscreen windows with the game or video
  # content type, as niri's on-demand VRR did; game-vrr.nix marks games. VRR
  # on an OLED desktop flickers as the refresh rate changes.
  #
  # Hyprland matches desc: against the start of "make model serial". Each
  # hl.monitor call has to stay on one line, since DMS reads the file back
  # line by line.
  modules.hyprland.outputs = ''
    hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })
    hl.monitor({ output = "desc:ASUSTek COMPUTER INC XG27AQWMG TCLMTF074235", mode = "2560x1440@279.961", position = "0x0", scale = 1, vrr = 3, bitdepth = 10, cm = "hdr" })
  '';
}
