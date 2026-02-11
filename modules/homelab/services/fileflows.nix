{
  config,
  lib,
  ...
}:
let
  shareUser = "share";
  shareGroup = "share";
  shareUid = 995;
  shareGid = 995;
  port = 5000;
  domain = "ff.schnitzelflix.xyz";
in
{
  options.services.fileflows-wrapped = {
    enable = lib.mkEnableOption "FileFlows media processing with Caddy integration";
  };

  config = lib.mkIf config.services.fileflows-wrapped.enable {
    virtualisation.oci-containers.containers.fileflows = {
      image = "revenz/fileflows";
      environment = {
        TempPathHost = "/tmp/fileflows";
        TZ = "Europe/Vienna";
        PUID = toString shareUid;
        PGID = toString shareGid;
      };
      volumes = [
        "/tmp/fileflows:/temp"
        "/var/lib/fileflows/data:/app/Data"
        "/var/lib/fileflows/logs:/app/Logs"
        "/mnt/downloads:/mnt/downloads"
        "/tank/media:/media"
      ];
      extraOptions = [
        "--network=host"
        "--device=/dev/dri:/dev/dri"
      ];
    };

    # Create required directories with proper permissions
    systemd.tmpfiles.rules = [
      "d /tmp/fileflows 2775 ${shareUser} ${shareGroup} -"
      "d /var/lib/fileflows 2775 ${shareUser} ${shareGroup} -"
      "d /var/lib/fileflows/data 2775 ${shareUser} ${shareGroup} -"
      "d /var/lib/fileflows/logs 2775 ${shareUser} ${shareGroup} -"
    ];

    # Caddy virtual host configuration with basic auth
    services.caddy-wrapper.virtualHosts."fileflows" = {
      inherit domain;
      extraConfig = ''
        reverse_proxy 127.0.0.1:${toString port}
      '';
    };
  };
}
