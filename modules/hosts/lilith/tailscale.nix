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
    extraSetFlags = [
      # Flint provides tailnet DNS.
      "--accept-dns=true"
      # Lilith sits on Flint's 10.0.0.0/24. Tailscale's routing table takes
      # precedence over main, so accepting that route pulled LAN traffic,
      # the gateway and DNS included, into the tunnel. An exit node, Flint
      # or any other, did the same to all traffic and cut off the internet.
      "--accept-routes=false"
      "--exit-node="
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
