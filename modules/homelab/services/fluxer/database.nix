{
  config,
  lib,
  ...
}: let
  cfg = config.services.homelab.fluxer;
in {
  config = lib.mkIf cfg.enable {
    # fluxer-nix uses the host's shared cluster on the SSD, over the socket
    # as the fluxer role. It sits outside tank/fluxer's quota and snapshots,
    # so the database needs its own backup. Fluxer's four pools can use 90
    # connections; leave room for other host services.
    services.postgresql.settings.max_connections = lib.mkDefault 200;
  };
}
