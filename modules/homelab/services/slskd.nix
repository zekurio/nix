{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.slskd-wrapped;
  domain = "slskd.zekurio.xyz";
  webPort = 5030;
  musicDir = "/tank/media/music";
  downloadDir = "/mnt/downloads/complete/slskd";
  incompleteDir = "/mnt/downloads/incomplete/slskd";

  # Beets import script triggered by slskd on download completion
  slskdImportFiles = pkgs.writeShellScript "slskd-import-files" ''
    cd /var/lib/beets
    HOME=/var/lib/beets ${lib.getExe pkgs.beets} \
      -c ${config.services.beets-wrapped.configFile} \
      import -m -q ${downloadDir}
  '';
in {
  options.services.slskd-wrapped = {
    enable = lib.mkEnableOption "slskd Soulseek client with Caddy integration";
  };

  config = lib.mkIf cfg.enable {
    services.slskd = {
      enable = true;
      openFirewall = true;
      domain = null;
      environmentFile = config.sops.secrets.slskd_env.path;
      settings = {
        directories = {
          downloads = downloadDir;
          incomplete = incompleteDir;
        };
        shares = {
          directories = [musicDir];
          filters = [
            "\\.ini$"
            "Thumbs.db$"
            "\\.DS_Store$"
          ];
        };
        integration.scripts.slskd-import-files = {
          on = [
            "DownloadDirectoryComplete"
            "DownloadFileComplete"
          ];
          run = {
            executable = "${lib.getExe pkgs.bash}";
            command = "-c ${slskdImportFiles}";
          };
        };
        web = {
          port = webPort;
          https.disabled = true;
        };
      };
    };

    # Grant slskd access to media and download paths
    systemd.services.slskd.serviceConfig.ReadWritePaths = [
      musicDir
      downloadDir
      incompleteDir
      "/var/lib/beets"
    ];

    # SOPS secret for slskd credentials
    sops.secrets.slskd_env = {
      owner = config.services.slskd.user;
      group = config.services.slskd.group;
      mode = "0400";
    };

    # Caddy reverse proxy
    services.caddy-wrapper.virtualHosts."slskd" = {
      inherit domain;
      reverseProxy = "127.0.0.1:${toString webPort}";
    };
  };
}
