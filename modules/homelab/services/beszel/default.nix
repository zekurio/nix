{
  flake.modules.nixos.homelab = {
    config,
    lib,
    ...
  }: let
    cfg = config.services.homelab.beszel;
    hub = config.services.beszel.hub;
    domain = "status.${config.services.homelab.domains.zekurio}";
    downloadsRoot = config.services.homelab.mediaShare.downloadsRoot;
  in {
    options.services.homelab.beszel.enable = lib.mkEnableOption "Beszel monitoring hub with a local agent";

    config = lib.mkIf cfg.enable {
      services.beszel.hub = {
        enable = true;
        # Alert notifications link back to the hub through this URL.
        environment.APP_URL = "https://${domain}";
      };

      services.beszel.agent = {
        enable = true;
        smartmon.enable = true;
        environment = {
          # Only the hub on this host dials in; add the system there as
          # 127.0.0.1, port 45876.
          LISTEN = "127.0.0.1:45876";
          # Public half of the key the hub generated on its first start in
          # /var/lib/beszel-hub/beszel_data. The hub makes a new one if that
          # state is lost; pin the key it then shows under "Add system".
          KEY = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHtwOnKoqzxnY1pOE53nO8OA50xscwJQDoFrl3uCjlvo";
          # Root and the ZFS pools appear on their own. The downloads disk and
          # the media dataset's quota are where imports stall first.
          EXTRA_FILESYSTEMS = "${downloadsRoot}__Downloads,/tank/media__Media";
        };
      };

      services.homelab.caddy.virtualHosts.beszel = {
        inherit domain;
        reverseProxy = "${hub.host}:${toString hub.port}";
      };
    };
  };
}
