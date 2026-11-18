{
  lib,
  pkgs,
  ...
}: let
  xembsni = pkgs.callPackage ./_xembsni.nix {};
in {
  # Wine and Proton only dock tray icons through the X11 XEmbed protocol,
  # which DMS's Quickshell tray does not speak. Without an X11 tray owner,
  # Wine opens its own "Wine System Tray" window instead. xembsni takes the
  # X11 tray on Hyprland's Xwayland display and republishes each icon as a
  # StatusNotifierItem.
  #
  # Start Wine apps after xembsni. When the tray owner changed under a
  # running app on niri's xwayland-satellite, Wine re-docked its icon as a
  # briefly top-level window that the satellite marked WM_STATE Withdrawn.
  # Wine then ignored the icon's moves and dropped every click as outside
  # it, so a restarted xembsni left existing icons visible but dead until
  # their app restarted. Hyprland's Xwayland may not do this; untested.
  systemd.user.services.xembsni = {
    description = "XEmbed to StatusNotifierItem tray bridge";
    partOf = ["graphical-session.target"];
    after = ["graphical-session.target"];
    wantedBy = ["graphical-session.target"];
    # Quickshell activates tray items at (0, 0), so xembsni opens Wine's
    # menus at this corner of the work area. It is xembsni's default, set
    # here because it must follow the tray's place in DMS's bar settings.
    serviceConfig = {
      ExecStart = "${lib.getExe xembsni} --menu-anchor top-right";
      Restart = "on-failure";
      RestartSec = 2;
    };
  };

  # xembsni reparents each icon into an offscreen container window, but
  # Hyprland still maps it as a toplevel and would tile it like a normal
  # window. The container floats as an unfocusable, transparent pixel in the
  # corner instead. xembsni names its class for this.
  modules.hyprland.extraConfig = ''
    hl.window_rule({
        match = { class = [[^xembsni$]] },
        float = true,
        no_initial_focus = true,
        no_focus = true,
        size = { 1, 1 },
        move = { 0, 0 },
        opacity = "0.0 override 0.0 override 0.0 override",
        border_size = 0,
        no_shadow = true,
        no_blur = true,
        no_anim = true,
    })
  '';
}
