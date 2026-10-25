{
  # The upstream unit has no ordering, so graphical-session.target starts it
  # alongside KWin, before KWin exports WAYLAND_DISPLAY and DISPLAY. Every
  # extractor baloo_file spawns inherits that empty environment, finds no Qt
  # platform plugin and aborts. Plasma ships the unit through pathsToLink
  # rather than systemd.packages, so a plain definition would replace it
  # instead of extending it.
  systemd.user.services.kde-baloo = {
    overrideStrategy = "asDropin";
    after = ["plasma-core.target"];
    # Keep the session PATH instead of the minimal one NixOS adds to units.
    enableDefaultPath = false;
  };
}
