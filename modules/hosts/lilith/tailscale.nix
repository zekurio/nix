{
  config,
  lib,
  ...
}: {
  services.tailscale = {
    enable = true;
    # UDP 41641 inbound lets peers connect directly instead of falling
    # back to DERP relays.
    openFirewall = true;
    # Linux rejects advertised subnet routes by default. Flint provides
    # both the 10.0.0.0/24 route and tailnet DNS.
    useRoutingFeatures = "client";
    extraSetFlags = [
      "--accept-dns=true"
      "--accept-routes=true"
      "--hostname=lilith"
      # Without operator rights the tray can show status but not log in,
      # connect or disconnect; tailscaled only takes those from root.
      "--operator=zekurio"
    ];
  };

  # Tailscale's built-in tray publishes a StatusNotifierItem, which DMS's
  # Quickshell tray shows. Restart covers a session where the tray's
  # watcher is not up yet.
  systemd.user.services.tailscale-systray = {
    description = "Tailscale tray icon";
    partOf = ["graphical-session.target"];
    after = ["graphical-session.target"];
    wantedBy = ["graphical-session.target"];
    serviceConfig = {
      ExecStart = "${lib.getExe config.services.tailscale.package} systray";
      Restart = "on-failure";
      RestartSec = 2;
    };
  };
}
