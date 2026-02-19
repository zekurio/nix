{
  config,
  lib,
  ...
}: let
  cfg = config.services.fileflows-wrapped;
  shareUser = "share";
  shareGroup = "share";
  shareUid = 995;
  shareGid = 995;
  port = 5000;
  domain = "ff.schnitzelflix.xyz";
  # Client ID is a public identifier — fill in after creating the OIDC client
  # in Pocket ID. The client secret lives in the SOPS secret below.
  oidcClientId = ""; # TODO: paste from Pocket ID
in {
  options.services.fileflows-wrapped = {
    enable = lib.mkEnableOption "FileFlows media processing with Caddy integration";
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.containers.fileflows = {
      image = "revenz/fileflows";
      environment = {
        TempPathHost = "/tmp/fileflows";
        TZ = "Europe/Vienna";
        PUID = toString shareUid;
        PGID = toString shareGid;
        # Native OIDC — Pocket ID as the identity provider
        OidcAuthority = "https://auth.zekurio.xyz";
        OidcClientId = oidcClientId;
        OidcCallbackAddress = "https://${domain}";
      };
      environmentFiles = [config.sops.secrets.fileflows_oidc_env.path];
      volumes = [
        "/tmp/fileflows:/temp"
        "/var/lib/fileflows/data:/app/Data"
        "/var/lib/fileflows/logs:/app/Logs"
        "/mnt/downloads:/mnt/downloads"
        "/tank/media:/tank/media"
      ];
      extraOptions = [
        "--network=host"
        "--device=/dev/dri:/dev/dri"
      ];
    };

    sops.secrets.fileflows_oidc_env = {
      # container runs as shareUid/shareGid; caddy/podman reads the secret
      mode = "0444";
    };

    systemd.tmpfiles.rules = [
      "d /tmp/fileflows 2775 ${shareUser} ${shareGroup} -"
      "d /var/lib/fileflows 2775 ${shareUser} ${shareGroup} -"
      "d /var/lib/fileflows/data 2775 ${shareUser} ${shareGroup} -"
      "d /var/lib/fileflows/logs 2775 ${shareUser} ${shareGroup} -"
    ];

    services.caddy-wrapper.virtualHosts."fileflows" = {
      inherit domain;
      extraConfig = ''
        reverse_proxy 127.0.0.1:${toString port}
      '';
    };
  };
}
