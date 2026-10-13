{inputs, ...}: {
  flake.modules.nixos.homelab = {
    config,
    lib,
    ...
  }: let
    cfg = config.services.homelab.blitzcrank-mcp;
    port = 8485;
    shareGroup = config.services.homelab.mediaShare.group;
    downloadsRoot = config.services.homelab.mediaShare.downloadsRoot;
  in {
    imports = [
      inputs.blitzcrank.nixosModules.blitzcrank-mcp
    ];

    options.services.homelab.blitzcrank-mcp = {
      enable = lib.mkEnableOption "Blitzcrank MCP server for the media stack";
      url = lib.mkOption {
        type = lib.types.str;
        default = "http://127.0.0.1:${toString port}/mcp";
        description = "MCP endpoint the Blitzcrank host connects to.";
      };
    };

    config = lib.mkIf cfg.enable {
      services.blitzcrank-mcp = {
        enable = true;
        inherit port;

        # Directories the media tools may inspect with ffprobe and ffmpeg, and
        # nothing else. Include SABnzbd's completed tree and the imported
        # libraries. Music and the private tree are deliberately absent: Seerr
        # issues never concern them.
        mediaRoots = [
          downloadsRoot
          "/tank/media/shows"
          "/tank/media/anime"
          "/tank/media/movies"
        ];
        # The unit runs as a dynamic user, which reads the media tree only as
        # a member of the share group.
        supplementaryGroups = [shareGroup];
        environmentFile = config.sops.templates."blitzcrank-mcp.env".path;

        # Non-secret configuration; the token and every API key live in the env
        # template. A service is served only when both its URL and key are set.
        settings = {
          SEERR_URL = config.services.homelab.seerr.baseUrl;
          SONARR_URL = config.services.homelab.sonarr.baseUrl;
          RADARR_URL = config.services.homelab.radarr.baseUrl;
          SABNZBD_URL = config.services.homelab.sabnzbd.baseUrl;
          JELLYFIN_URL = config.services.homelab.jellyfin.baseUrl;
        };
      };

      sops.templates."blitzcrank-mcp.env" = {
        content = ''
          BLITZCRANK_MCP_TOKEN=${config.sops.placeholder.blitzcrank_mcp_token}
          SEERR_API_KEY=${config.sops.placeholder.seerr_api_key}
          SONARR_API_KEY=${config.sops.placeholder.sonarr_api_key}
          RADARR_API_KEY=${config.sops.placeholder.radarr_api_key}
          SABNZBD_API_KEY=${config.sops.placeholder.sabnzbd_api_key}
          JELLYFIN_API_KEY=${config.sops.placeholder.jellyfin_api_key}
        '';
        mode = "0400";
        # Rendering a changed template does not touch the unit, so without this
        # a rotated key would sit unread until the next unrelated restart.
        restartUnits = ["blitzcrank-mcp.service"];
      };

      sops.secrets = {
        # The host presents the same token on every request.
        blitzcrank_mcp_token = {};
        seerr_api_key = {};
        sonarr_api_key = {};
        radarr_api_key = {};
        sabnzbd_api_key = {};
        jellyfin_api_key = {};
      };
    };
  };
}
