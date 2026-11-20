let
  asus = "desc:ASUSTek COMPUTER INC XG27AQWMG TCLMTF074235";
in {
  # The ASUS XG27AQWMG's EDID advertises 10 bits per channel, BT.2020 and
  # SMPTE ST 2084.
  #
  # The desktop runs in SDR with the sRGB preset. Hyprland's "auto" preset
  # would pick "wide" at 10 bits, which signals BT.2020 colorimetry that a
  # monitor in an SDR picture mode may ignore, desaturating everything. For
  # accurate SDR colours, use the monitor's sRGB Cal mode instead.
  # render.cm_auto_hdr, on by default, switches to HDR while a fullscreen
  # window shows HDR content; hdr/default.nix switches the whole desktop.
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
    hl.monitor({ output = "${asus}", mode = "2560x1440@279.961", position = "0x0", scale = 1, vrr = 3, bitdepth = 10 })
  '';

  modules.hdr.outputs.${asus} = {
    sdr = {
      cm = "srgb";
      # Match render.cm_sdr_eotf below so SDR shadows don't shift when
      # switching between SDR and HDR.
      sdr_eotf = "gamma22";
    };

    hdr = {
      # BT.2020 primaries. "hdredid" would take the EDID's, which Hyprland
      # documents as inaccurate; the monitor clamps BT.2020 itself in HDR.
      cm = "hdr";
      sdr_eotf = "gamma22";
      # SDR windows otherwise map black to 0.2 nits, a grey veil on an OLED.
      sdr_min_luminance = 0;
      # SDR white at the BT.2408 reference level. Hyprland's sdrbrightness
      # scales PQ code values instead of light, which also shifts the tone
      # curve, so it stays at 1.0; raise this for a brighter desktop.
      sdr_max_luminance = 203;
      # The EDID claims 603 nits, which only holds for the HDR modes'
      # default brightness of 70. TFTCentral's preferred setup, HDR Gaming
      # with "Adjustable HDR" and brightness 100, peaks at 1639 nits on a 1%
      # window with firmware MCM102. Tell Hyprland and the apps the rated
      # 1500, so they stop tone-mapping highlights down to 603. With True
      # Black 500 or the default brightness, drop this to go back to the
      # EDID value.
      max_luminance = 1500;
    };
  };

  # gamma22force also treats windows tagged sRGB as gamma 2.2, so a
  # colour-managed app like Helium matches unmanaged ones.
  modules.hyprland.extraConfig = ''
    hl.config({ render = { cm_sdr_eotf = "gamma22force" } })
  '';
}
