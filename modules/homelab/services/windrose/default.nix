{
  flake.modules.nixos.homelab = {
    config,
    lib,
    ...
  }: let
    cfg = config.services.homelab.windrose;
    dataDir = "/var/lib/windrose/server-files";
  in {
    options.services.homelab.windrose = {
      enable = lib.mkEnableOption "Windrose dedicated server (Docker container)";

      image = lib.mkOption {
        type = lib.types.str;
        default = "indifferentbroccoli/windrose-server-docker:latest";
        description = "Container image to run.";
      };

      serverName = lib.mkOption {
        type = lib.types.str;
        default = "zekurio's Windrose server";
        description = "Display name shown to players.";
      };

      maxPlayers = lib.mkOption {
        type = lib.types.ints.positive;
        default = 10;
        description = "Maximum simultaneous players.";
      };

      region = lib.mkOption {
        type = lib.types.enum ["EU" "SEA" "CIS"];
        default = "EU";
        description = "Region for the connection service.";
      };

      updateOnStart = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Download and validate server files on every startup.";
      };

      useDirectConnection = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          When true, players connect via public IP and port (requires port
          forwarding on the router). When false, players join via invite code
          using the P2P/ICE protocol — no port forwarding required.
        '';
      };

      serverPort = lib.mkOption {
        type = lib.types.port;
        default = 7777;
        description = "Direct-connection port (TCP+UDP). Only used when useDirectConnection = true.";
      };

      hostNetwork = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Run the container with host networking. Required for LAN players to
          join in invite-code mode; must be paired with p2pProxyAddress set to
          the host's LAN IP.
        '';
      };

      p2pProxyAddress = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = ''
          IP the P2P proxy binds to. Keep 127.0.0.1 for internet-only invite
          mode. Set to the host's LAN IP when players on the same network need
          to connect (requires hostNetwork = true).
        '';
      };

      environmentFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = config.sops.secrets.windrose_env.path or null;
        defaultText = lib.literalExpression "config.sops.secrets.windrose_env.path";
        description = ''
          Env file containing sensitive values such as INVITE_CODE or
          SERVER_PASSWORD. Defaults to the SOPS-managed windrose_env secret.
        '';
      };
    };

    config = lib.mkIf cfg.enable {
      virtualisation.oci-containers.containers.windrose = {
        image = cfg.image;
        autoStart = true;
        extraOptions =
          ["--stop-timeout=30"]
          ++ lib.optional cfg.hostNetwork "--network=host";

        environment = {
          PUID = "1000";
          PGID = "1000";
          UPDATE_ON_START = lib.boolToString cfg.updateOnStart;
          USE_DIRECT_CONNECTION = lib.boolToString cfg.useDirectConnection;
          SERVER_PORT = toString cfg.serverPort;
          DIRECT_CONNECTION_PROXY_ADDRESS = "0.0.0.0";
          USER_SELECTED_REGION = cfg.region;
          SERVER_NAME = cfg.serverName;
          MAX_PLAYERS = toString cfg.maxPlayers;
          P2P_PROXY_ADDRESS = cfg.p2pProxyAddress;
          GENERATE_SETTINGS = "true";
          WINDROSE_PLUS_ENABLED = "true";
        };

        environmentFiles = lib.optional (cfg.environmentFile != null) cfg.environmentFile;

        ports = lib.optionals (cfg.useDirectConnection && !cfg.hostNetwork) [
          "${toString cfg.serverPort}:${toString cfg.serverPort}/tcp"
          "${toString cfg.serverPort}:${toString cfg.serverPort}/udp"
        ];

        volumes = [
          "${dataDir}:/home/steam/server-files"
        ];
      };

      systemd.tmpfiles.rules = [
        "d /var/lib/windrose 0755 1000 1000 -"
        "d ${dataDir} 0755 1000 1000 -"
      ];

      networking.firewall = lib.mkIf cfg.useDirectConnection {
        allowedTCPPorts = [cfg.serverPort];
        allowedUDPPorts = [cfg.serverPort];
      };

      sops.secrets.windrose_env = {
        mode = "0400";
      };
    };
  };
}
