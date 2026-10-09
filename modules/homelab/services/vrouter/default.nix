{inputs, ...}: {
  flake.modules.nixos.homelab = {
    config,
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
      enable = lib.mkEnableOption "vrouter model gateway with Caddy integration";
    };

    config = lib.mkIf cfg.enable {
      services.vrouter = {
        enable = true;
        # The upstream module's default builds against this host's nixpkgs
        # instead of the flake's own package output.
        package = inputs.vrouter.packages.${pkgs.stdenv.hostPlatform.system}.default;
        inherit port;
        # Management writes are only accepted from this origin, and Caddy
        # preserves the Host header that vrouter checks against it.
        publicUrl = "https://${domain}";
        environmentFile = config.sops.secrets.vrouter_env.path;
      };

      # Holds VROUTER_ADMIN_TOKEN. Caddy's source range filter is not
      # authentication, so every device on the LAN or tailnet would otherwise
      # administer the stored provider credentials.
      sops.secrets.vrouter_env = {
        mode = "0400";
        # EnvironmentFile is read once at start.
        restartUnits = ["vrouter.service"];
      };

      # Private vhost: the dashboard and /v1 inference answer only the LAN and
      # tailnet.
      services.homelab.caddy.virtualHosts.vrouter = {
        inherit domain;
        reverseProxy = "127.0.0.1:${toString port}";
      };
    };
  };
}
