{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.oauth2-proxy-wrapped;
  serviceUser = "oauth2-proxy";
  serviceGroup = "oauth2-proxy";

  oidcIssuerUrl = "https://auth.zekurio.xyz";

  # Client IDs are public identifiers — fill these in after creating the OIDC
  # clients in Pocket ID. Secrets live in the SOPS env files below.
  clientIdSchnitzelflix = "80266961-c063-4ad5-89aa-6db676a78654";
  clientIdZekurio = "b69058a1-6a3d-4f1e-8217-4f654fac27de";

  portSchnitzelflix = 4180;
  portZekurio = 4181;

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
    after = ["network.target" "pocket-id.service"];
    serviceConfig = {
      User = serviceUser;
      Group = serviceGroup;
      EnvironmentFile = config.sops.secrets.${secretName}.path;
      ExecStart = lib.escapeShellArgs (
        ["${pkgs.oauth2-proxy}/bin/oauth2-proxy"]
        ++ mkArgs {inherit clientId port cookieDomain;}
      );
      Restart = "on-failure";
      RestartSec = "5s";
    };
  };
in {
  options.services.oauth2-proxy-wrapped = {
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
      cookieDomain = ".zekurio.xyz";
      secretName = "oauth2_proxy_zekurio_env";
    };
  };
}
