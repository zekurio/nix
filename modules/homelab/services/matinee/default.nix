{
  config,
  inputs,
  lib,
  ...
}: let
  cfg = config.services.homelab.matinee;
  domain = "media.${config.services.homelab.domains.zekurio}";
  # The A380, which Jellyfin, Immich, and Alloy share.
  renderNode = "/dev/dri/renderD128";
in {
  imports = [
    inputs.matinee.nixosModules.default
  ];

  options.services.homelab.matinee = {
    enable = lib.mkEnableOption "Matinee, the media server that replaces Jellyfin";
  };

  config = lib.mkIf cfg.enable {
    services.matinee = {
      enable = true;
      publicUrl = "https://${domain}";
      # Read access to /tank/media is all it needs.
      extraGroups = [config.services.homelab.mediaShare.group];
      transcoding = {
        hardwareAcceleration = "qsv";
        # Naming the node limits DeviceAllow to it. Left null, Matinee
        # searches for the Intel GPU and the unit may open every device.
        qsvDevice = renderNode;
      };
    };

    systemd.services.matinee.environment.LIBVA_DRIVER_NAME = "iHD";

    services.homelab.backup.stopUnits = ["matinee.service"];

    # Public, as Jellyfin was: the Android app and browsers outside the
    # tailnet stream through it.
    services.homelab.caddy.virtualHosts.matinee = {
      inherit domain;
      public = true;
      reverseProxy = "127.0.0.1:${toString config.services.matinee.port}";
    };
  };
}
