{
  flake.modules.nixos.homelab = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.homelab.oauth2-proxy;
    serviceUser = "oauth2-proxy";
    serviceGroup = "oauth2-proxy";

    oidcIssuerUrl = "https://auth.${config.services.homelab.domains.zekurio}";

    # Client IDs are public identifiers — fill these in after creating the OIDC
    # clients in Pocket ID. Secrets live in the SOPS env files below.
    clientIdSchnitzelflix = "80266961-c063-4ad5-89aa-6db676a78654";
    clientIdZekurio = "b69058a1-6a3d-4f1e-8217-4f654fac27de";

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
      listenAddress,
      cookieDomain,
      extraArgs ? [],
    }:
      [
        "--provider=oidc"
        "--oidc-issuer-url=${oidcIssuerUrl}"
        "--client-id=${clientId}"
        "--http-address=${listenAddress}"
        "--cookie-domain=${cookieDomain}"
        "--whitelist-domain=${cookieDomain}"
        # Allow any email; Pocket ID manages which users can access each client
        "--email-domain=*"
        # Sessions must carry Pocket ID group membership so the admin instance
        # can evaluate --allowed-group against them. Sessions issued before
        # this scope was added hold no groups and fail the check on re-use.
        "--scope=openid email profile groups"
        "--skip-provider-button=true"
        "--reverse-proxy=true"
        "--trusted-proxy-ip=127.0.0.1/32"
        "--trusted-proxy-ip=::1/128"
        "--set-xauthrequest=true"
        "--proxy-prefix=/oauth2"
        # Skip auth check on oauth2-proxy's own routes
        "--skip-auth-regex=^/oauth2/"
      ]
      ++ extraArgs;

    mkService = {
      name,
      clientId,
      listenAddress,
      cookieDomain,
      secretName,
      extraArgs ? [],
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
          ++ mkArgs {inherit clientId listenAddress cookieDomain extraArgs;}
        );
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };
  in {
    options.services.homelab.oauth2-proxy = {
      enable = lib.mkEnableOption "oauth2-proxy OIDC forward auth for Caddy";
      schnitzelflix.forwardAuthAddress = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1:4180";
        description = "Listen address of the schnitzelflix oauth2-proxy instance; also the forward_auth upstream for its vhosts.";
      };
      zekurio.forwardAuthAddress = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1:4181";
        description = "Listen address of the zekurio oauth2-proxy instance; also the forward_auth upstream for its vhosts.";
      };
      admin.forwardAuthAddress = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1:4182";
        description = "Listen address of the admin oauth2-proxy instance; the forward_auth upstream for vhosts gating admin paths.";
      };
      admin.allowedGroup = lib.mkOption {
        type = lib.types.str;
        default = "admin";
        description = "Pocket ID group required by the admin instance. The other instances accept any user, so this check is what makes an admin gate admin-only.";
      };
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
        listenAddress = cfg.schnitzelflix.forwardAuthAddress;
        cookieDomain = ".${config.services.homelab.domains.schnitzelflix}";
        secretName = "oauth2_proxy_schnitzelflix_env";
      };

      systemd.services.oauth2-proxy-zekurio = mkService {
        name = "zekurio";
        clientId = clientIdZekurio;
        listenAddress = cfg.zekurio.forwardAuthAddress;
        cookieDomain = ".${config.services.homelab.domains.zekurio}";
        secretName = "oauth2_proxy_zekurio_env";
      };

      # Shares the zekurio client, secrets and cookie domain with the main
      # instance, so a login on any zekurio.me service is a valid session
      # here too; the group check runs per request against the groups stored
      # in that session.
      systemd.services.oauth2-proxy-admin = mkService {
        name = "admin";
        clientId = clientIdZekurio;
        listenAddress = cfg.admin.forwardAuthAddress;
        cookieDomain = ".${config.services.homelab.domains.zekurio}";
        secretName = "oauth2_proxy_zekurio_env";
        extraArgs = ["--allowed-group=${cfg.admin.allowedGroup}"];
      };
    };
  };
}
