{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.homelab.jellything;
  domain = "invite.schnitzelflix.xyz";
  port = 4173;
  package = inputs.jellything.packages.${pkgs.system}.default.overrideAttrs (finalAttrs: _: {
    pnpmDeps = pkgs.fetchPnpmDeps {
      inherit (finalAttrs) pname version src;
      fetcherVersion = 3;
      hash = "sha256-yxLZI1+gZpl6le1MNjPZgGzmz/VKIy7N+BrvS6MhfBI=";
    };
  });
in {
  imports = [
    inputs.jellything.nixosModules.default
  ];

  options.services.homelab.jellything = {
    enable = lib.mkEnableOption "Jellything user management and invitations with Caddy integration";
  };

  config = lib.mkIf cfg.enable {
    services.jellything = {
      enable = true;
      inherit package;
      host = "127.0.0.1";
      inherit port;
      dataDir = "/var/lib/jellything";
      logLevel = "info";
    };

    services.homelab.caddy.virtualHosts."jellything" = {
      inherit domain;
      reverseProxy = "127.0.0.1:${toString port}";
    };
  };
}
