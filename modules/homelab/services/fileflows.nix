{
  lib,
  config,
  ...
}: let
  cfg = config.services.fileflows-wrapped;
  domain = "ff.schnitzelflix.xyz";
  port = 5000;
in {
  options.services.fileflows-wrapped = {
    enable = lib.mkEnableOption "FileFlows with Caddy integration";
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.containers.fileflows = {
      image = "revenz/fileflows";
      autoRemoveOnStop = false;
      devices = ["/dev/dri:/dev/dri"];
      environment = {
        TempPathHost = "/tmp/fileflows";
        TZ = "Europe/Vienna";
        PUID = "995";
        PGID = "995";
      };
      volumes = [
        "/run/podman/podman.sock:/var/run/docker.sock:ro"
        "/tmp/fileflows:/temp"
        "fileflows_data:/app/Data"
        "fileflows_logs:/app/Logs"
        "/mnt/downloads:/mnt/downloads"
        "/tank/media:/tank/media"
      ];
      extraOptions = [
        "--restart=unless-stopped"
        "--network=host"
      ];
    };

    systemd.tmpfiles.rules = [
      "d /tmp/fileflows 0775 share share -"
    ];

    services.caddy-wrapper.virtualHosts."fileflows" = {
      inherit domain;
      forwardAuth = "127.0.0.1:4180";
      reverseProxy = "127.0.0.1:${toString port}";
    };
  };
}
