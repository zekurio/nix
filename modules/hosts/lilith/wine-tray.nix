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
  # X11 tray on xwayland-satellite's display and republishes each icon as a
  # StatusNotifierItem.
  #
  # Start Wine apps after xembsni. When the tray owner changes under a
  # running app, Wine re-docks its icon as a briefly top-level window that
  # xwayland-satellite marks WM_STATE Withdrawn. Wine then ignores the
  # icon's moves and drops every click as outside it, so a restarted
  # xembsni leaves existing icons visible but dead until their app restarts.
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
  # xwayland-satellite still maps it as a toplevel and niri tiles it like a
  # normal window. niri cannot hide windows, so the container floats as an
  # unfocused, transparent pixel in the corner. xembsni names it for this.
  modules.niri.extraConfig = ''
    window-rule {
        match app-id="^xembsni$"
        open-floating true
        open-focused false
        default-column-width { fixed 1; }
        default-window-height { fixed 1; }
        default-floating-position x=0 y=0 relative-to="bottom-left"
        opacity 0.0
        focus-ring { off; }
        border { off; }
        shadow { off; }
    }
  '';
}
