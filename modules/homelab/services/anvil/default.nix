{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.homelab.anvil;
  mediaShare = config.services.homelab.mediaShare;
  domain = config.services.homelab.domains.admin;
  packages = inputs.anvil.packages.${pkgs.stdenv.hostPlatform.system};
  # Blitzcrank holds 8484, Anvil's default, and its MCP server 8485.
  port = 8486;
in {
  imports = [inputs.anvil.nixosModules.default];

  options.services.homelab.anvil.enable =
    lib.mkEnableOption "Anvil media encoding daemon with its web UI behind Caddy";

  config = lib.mkIf cfg.enable {
    services.anvil = {
      enable = true;
      package = packages.anvild;
      user = mediaShare.user;
      group = mediaShare.group;
      controlClient = {
        install = true;
        package = packages.anvilctl;
      };

      # Libraries, flows, and Arr connections live in the web UI's store.
      # This list bounds where the UI may point them and what the unit may
      # write. Media libraries replace files in place, so it names the video
      # libraries only, not all of /tank/media.
      mediaPaths = [
        mediaShare.downloadsRoot
        "/tank/media/movies"
        "/tank/media/shows"
        "/tank/media/anime"
      ];

      web = {
        inherit port;
        basePath = "/anvil";
        # Caddy reaches the UI over loopback but forwards the admin domain as
        # Host, which an unauthenticated daemon refuses. The shared admin
        # password lifts that check and gives the UI its sign-in.
        passwordFile = config.sops.secrets.admin_password.path;
      };

      service.extraServiceConfig = {
        SupplementaryGroups = [
          "homelab-admin"
          "render"
          "video"
        ];
        UMask = mediaShare.umask;
        # / is read-only under ProtectSystem=strict, so anything a tool
        # writes relative to its working directory lands in scratch instead.
        WorkingDirectory = "/var/lib/anvil/tmp";
      };
    };

    systemd.services.anvil = {
      # QSV encodes on adam's Intel GPU go through the iHD VA-API driver.
      environment.LIBVA_DRIVER_NAME = "iHD";
      # The unit reads /etc/anvil/anvil.toml, so a changed config would not
      # otherwise restart it.
      restartTriggers = [config.environment.etc."anvil/anvil.toml".source];
    };

    # Arr connections made in the web UI read their keys from these files,
    # so the share user must own them.
    sops.secrets = {
      radarr_api_key = {
        owner = mediaShare.user;
        group = mediaShare.group;
        mode = "0400";
      };
      sonarr_api_key = {
        owner = mediaShare.user;
        group = mediaShare.group;
        mode = "0400";
      };
    };

    services.homelab.caddy.virtualHosts."anvil" = {
      inherit domain;
      extraConfig = ''
        # Anvil serves under its base path itself and redirects /anvil to
        # /anvil/, so the prefix must reach it unstripped.
        @anvil path /anvil /anvil/*
        reverse_proxy @anvil 127.0.0.1:${toString port}
      '';
    };
  };
}
