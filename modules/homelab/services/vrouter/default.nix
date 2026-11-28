{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.homelab.vrouter;
  domain = "vrouter.${config.services.homelab.domains.zekurio}";
  port = 8787;
in {
  imports = [
    inputs.vrouter.nixosModules.default
  ];

  options.services.homelab.vrouter = {
    enable = lib.mkEnableOption "vrouter model gateway with admin key sign-in and Caddy integration";
    baseUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://127.0.0.1:${toString port}";
      description = "URL other services use to reach the vrouter API.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.vrouter = {
      enable = true;
      # The upstream module's default builds against this host's nixpkgs
      # instead of the flake's own package output.
      package = inputs.vrouter.packages.${pkgs.stdenv.hostPlatform.system}.default;
      inherit port;
      # Management writes are only accepted from this origin. Caddy preserves
      # the Host header that vrouter checks.
      publicUrl = "https://${domain}";
      # Opens the dashboard and the management API. The upstream module loads
      # it as a systemd credential, so the root-only sops file is enough.
      adminKeyFile = config.sops.secrets.vrouter_admin_key.path;
    };

    # The key is read once at start, and the dashboard cookie derives from it,
    # so a restart after rotation signs every browser out.
    sops.secrets.vrouter_admin_key.restartUnits = ["vrouter.service"];

    # Public: the dashboard and /api need the admin key, and /v1 inference
    # needs a vrouter API key.
    services.homelab.caddy.virtualHosts.vrouter = {
      inherit domain;
      public = true;
      reverseProxy = "127.0.0.1:${toString port}";
    };
  };
}
