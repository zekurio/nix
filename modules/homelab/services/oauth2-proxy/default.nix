{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.homelab.oauth2-proxy;
  serviceUser = "oauth2-proxy";
  serviceGroup = "oauth2-proxy";

  oidcIssuerUrl = "https://auth.zekurio.me";

  # Client IDs are public identifiers — fill these in after creating the OIDC
  # clients in Pocket ID. Secrets live in the SOPS env files below.
  clientIdSchnitzelflix = "80266961-c063-4ad5-89aa-6db676a78654";
  clientIdZekurio = "b69058a1-6a3d-4f1e-8217-4f654fac27de";

  portSchnitzelflix = 4180;
  portZekurio = 4181;

  caddyUnits = lib.optionals config.services.homelab.caddy.enable ["caddy.service"];
  waitForOidcDiscovery = pkgs.writeShellScript "oauth2-proxy-wait-for-oidc-discovery" ''
    set -eu

    url="${oidcIssuerUrl}/.well-known/openid-configuration"
    attempts=60
    attempt=1

    while [ "$attempt" -le "$attempts" ]; do
      if ${lib.getExe pkgs.curl} --fail --silent --output /dev/null --connect-timeout 1 --max-time 2 "$url"; then
        exit 0
      fi

      ${pkgs.coreutils}/bin/sleep 1
      attempt=$((attempt + 1))
    done

    echo "OIDC discovery endpoint did not become ready: $url" >&2
    exit 1
  '';

  mkArgs = {
    clientId,
    port,
    cookieDomain,
  }: [
    "--provider=oidc"
    "--oidc-issuer-url=${oidcIssuerUrl}"
    "--client-id=${clientId}"
    "--http-address=127.0.0.1:${toString port}"
    "--cookie-domain=${cookieDomain}"
    "--whitelist-domain=${cookieDomain}"
    # Allow any email; Pocket ID manages which users can access each client
    "--email-domain=*"
    "--skip-provider-button=true"
    "--reverse-proxy=true"
    "--trusted-proxy-ip=127.0.0.1/32"
    "--trusted-proxy-ip=::1/128"
    "--set-xauthrequest=true"
    "--proxy-prefix=/oauth2"
    # Skip auth check on oauth2-proxy's own routes
    "--skip-auth-regex=^/oauth2/"
  ];

  mkService = {
    name,
    clientId,
    port,
    cookieDomain,
    secretName,
  }: {
    description = "oauth2-proxy forward auth for ${cookieDomain}";
    wantedBy = ["multi-user.target"];
    wants = ["network-online.target" "pocket-id.service"] ++ caddyUnits;
    after = ["network-online.target" "pocket-id.service"] ++ caddyUnits;
    serviceConfig = {
      User = serviceUser;
      Group = serviceGroup;
      EnvironmentFile = config.sops.secrets.${secretName}.path;
      ExecStartPre = waitForOidcDiscovery;
      ExecStart = lib.escapeShellArgs (
        ["${pkgs.oauth2-proxy}/bin/oauth2-proxy"]
        ++ mkArgs {inherit clientId port cookieDomain;}
      );
      Restart = "on-failure";
      RestartSec = "5s";
    };
  };
in {
  options.services.homelab.oauth2-proxy = {
    enable = lib.mkEnableOption "oauth2-proxy OIDC forward auth for Caddy";
  };

  config = lib.mkIf cfg.enable {
    users.users.${serviceUser} = {
      isSystemUser = true;
      group = serviceGroup;
    };
    users.groups.${serviceGroup} = {};

    sops.secrets.oauth2_proxy_schnitzelflix_env = {
      owner = serviceUser;
      group = serviceGroup;
      mode = "0400";
    };
    sops.secrets.oauth2_proxy_zekurio_env = {
      owner = serviceUser;
      group = serviceGroup;
      mode = "0400";
    };

    systemd.services.oauth2-proxy-schnitzelflix = mkService {
      name = "schnitzelflix";
      clientId = clientIdSchnitzelflix;
      port = portSchnitzelflix;
      cookieDomain = ".schnitzelflix.xyz";
      secretName = "oauth2_proxy_schnitzelflix_env";
    };

    systemd.services.oauth2-proxy-zekurio = mkService {
      name = "zekurio";
      clientId = clientIdZekurio;
      port = portZekurio;
      cookieDomain = ".zekurio.me";
      secretName = "oauth2_proxy_zekurio_env";
    };
  };
}
