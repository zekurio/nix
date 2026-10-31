{
  config,
  lib,
  pkgs,
  ...
}: {
  config = lib.mkIf config.services.homelab.fluxer.enable {
    # fluxer-nix defaults every Redis server on the host to Valkey, Immich's
    # included. Immich's dump is in Redis 8's RDB format, which Valkey
    # cannot load. Fluxer only needs the protocol, so both stay on Redis.
    services.redis.package = pkgs.redis;
  };
}
