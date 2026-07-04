{
  config,
  inputs,
  lib,
  ...
}: let
  cfg = config.services.homelab.statusthing-agent;
in {
  imports = [
    inputs.statusthing.nixosModules.default
  ];

  options.services.homelab.statusthing-agent = {
    enable = lib.mkEnableOption "statusthing node agent";

    hubUrl = lib.mkOption {
      type = lib.types.str;
      description = "Base URL of the statusthing hub the agent pushes to.";
    };

    systemdUnits = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "systemd units the agent watches.";
    };

    watchContainers = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Watch containers via the system podman socket.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.statusthing-agent = {
      enable = true;
      hub.url = cfg.hubUrl;
      watch.systemdUnits = cfg.systemdUnits;
      watch.containers = {
        enable = cfg.watchContainers;
        socket = "/run/podman/podman.sock";
      };
      extraGroups = lib.optional cfg.watchContainers "podman";
      # Provides STATUSTHING_TOKEN, shared with the hub deployment.
      environmentFile = config.sops.secrets.statusthing_agent_env.path;
    };

    sops.secrets.statusthing_agent_env = {};
  };
}
