{
  # The ASUS XG27AQWMG's EDID advertises 10 bits per channel, BT.2020 and
  # SMPTE ST 2084, so Hyprland takes its luminance range from there.
  #
  # cm = "auto" keeps the desktop in SDR, with wide-gamut primaries at 10
  # bits. render.cm_auto_hdr, on by default, switches the output to HDR
  # while a fullscreen window shows HDR content, and windowed HDR content is
  # tone-mapped to SDR. cm = "hdr" would keep the whole desktop in HDR and
  # leave SDR windows to DMS's SDR brightness and saturation settings.
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
    hl.monitor({ output = "desc:ASUSTek COMPUTER INC XG27AQWMG TCLMTF074235", mode = "2560x1440@279.961", position = "0x0", scale = 1, vrr = 3, bitdepth = 10, cm = "auto" })
  '';

  # In SDR mode Hyprland reports the output as SDR to colour-managed
  # clients. Helium then never offers HDR video and Wine's Wayland driver
  # never exposes HDR to games, so the fullscreen switch above has nothing
  # to react to. prefer_hdr reports HDR as preferred while the desktop
  # itself stays in SDR.
  modules.hyprland.extraConfig = ''
    hl.config({ quirks = { prefer_hdr = 1 } })
  '';
}
