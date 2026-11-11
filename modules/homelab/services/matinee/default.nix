{
  config,
  inputs,
  lib,
  ...
}: let
  cfg = config.services.homelab.matinee;
  domain = "media.${config.services.homelab.domains.zekurio}";
  # Matinee's default, 8420, is where `pnpm dev` listens when Matinee is
  # worked on from adam.
  port = 8430;
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
      inherit port;
      # Read access to /tank/media is all it needs.
      extraGroups = [config.services.homelab.mediaShare.group];
      transcoding = {
        hardwareAcceleration = "qsv";
        # Naming the node limits DeviceAllow to it. Left null, Matinee
        # searches for the Intel GPU and the unit may open every device.
        qsvDevice = renderNode;
      };
      # Pocket ID's client for Matinee needs
      # <publicUrl>/api/auth/oidc/callback as its callback URL.
      oidc = {
        issuerUrl = "https://auth.${config.services.homelab.domains.zekurio}";
        # Not a secret: the browser sees it in every sign-in redirect.
        clientId = "283e9e6d-4fd9-4b46-a8fe-d17d8ff92f5a";
        displayName = "Pocket ID";
      };
      # Handed over through LoadCredential, so the file stays root-only.
      secrets.MATINEE_OIDC_CLIENT_SECRET = config.sops.secrets.matinee_oidc_client_secret.path;
    };

    sops.secrets.matinee_oidc_client_secret.restartUnits = ["matinee.service"];

    systemd.services.matinee.environment.LIBVA_DRIVER_NAME = "iHD";

    services.homelab.backup.stopUnits = ["matinee.service"];

    # Public, as Jellyfin was: the Android app and browsers outside the
    # tailnet stream through it.
    services.homelab.caddy.virtualHosts.matinee = {
      inherit domain;
      public = true;
      reverseProxy = "127.0.0.1:${toString port}";
    };
  };
}
