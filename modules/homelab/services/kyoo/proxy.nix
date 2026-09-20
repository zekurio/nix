{
  flake.modules.nixos.homelab = {
    config,
    lib,
    pkgs,
    ...
  }: let
    domain = "stream.${config.services.homelab.domains.zekurio}";
    # Keep Kyoo's upstream token exchange and CORS rules. Static routes avoid
    # giving the proxy access to the Podman socket.
    routes = pkgs.writeText "kyoo-routes.yaml" (builtins.toJSON {
      http = {
        routers = {
          front = {
            rule = "PathPrefix(`/`)";
            service = "front";
          };
          auth = {
            rule = "PathPrefix(`/auth/`) || PathPrefix(`/.well-known/`)";
            service = "auth";
          };
          swagger = {
            rule = "PathPrefix(`/swagger`)";
            service = "api";
          };
          api = {
            rule = "PathPrefix(`/api/`)";
            service = "api";
            middlewares = ["cors" "phantom-token"];
          };
          scanner = {
            rule = "PathPrefix(`/scanner/`)";
            service = "scanner";
            middlewares = ["phantom-token"];
          };
          transcoder = {
            rule = "PathPrefix(`/video`)";
            service = "transcoder";
            middlewares = ["cors" "phantom-token"];
          };
        };
        services =
          lib.mapAttrs (name: port: {
            loadBalancer.servers = [{url = "http://kyoo-${name}:${toString port}";}];
          }) {
            front = 8901;
            auth = 4568;
            api = 3567;
            scanner = 4389;
            transcoder = 7666;
          };
        middlewares = {
          phantom-token.forwardAuth = {
            address = "http://kyoo-auth:4568/auth/jwt";
            authRequestHeaders = ["Authorization" "Cookie" "X-Api-Key" "Sec-WebSocket-Protocol"];
            authResponseHeaders = ["Authorization"];
          };
          cors.headers = {
            accessControlAllowOriginList = ["*"];
            accessControlAllowMethods = ["GET" "OPTIONS"];
            accessControlAllowHeaders = ["Authorization" "Content-Type" "Range" "X-Api-Key"];
            addVaryHeader = true;
          };
        };
      };
    });
  in {
    config = lib.mkIf config.services.homelab.kyoo.enable {
      virtualisation.oci-containers.containers.kyoo-proxy = {
        image = "docker.io/library/traefik:v3.7";
        dependsOn = ["kyoo-auth" "kyoo-api" "kyoo-front" "kyoo-transcoder"];
        ports = ["127.0.0.1:8901:8901"];
        volumes = ["${routes}:/etc/traefik/routes.yaml:ro"];
        cmd = [
          "--providers.file.filename=/etc/traefik/routes.yaml"
          "--entryPoints.web.address=:8901"
          "--accesslog=true"
          "--accesslog.fields.queryparameters.defaultmode=drop"
        ];
      };
      services.homelab.caddy.virtualHosts.kyoo = {
        inherit domain;
        reverseProxy = "127.0.0.1:8901";
      };
    };
  };
}
