{
  flake.modules.nixos.homelab = {
    config,
    lib,
    ...
  }: let
    cfg = config.services.homelab.forgejo.runner;
    slice = "forgejo-runner.slice";
    network = "forgejo-runner";
    subnet = "10.90.0.0/24";
  in {
    options.services.homelab.forgejo.runner = {
      enable = lib.mkEnableOption "small Forgejo Actions runner";
      uuid = lib.mkOption {
        type = lib.types.str;
        description = "UUID shown when creating the runner in Forgejo.";
      };
    };

    config = lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = config.services.homelab.forgejo.enable;
          message = "The Forgejo runner requires services.homelab.forgejo.enable.";
        }
        {
          assertion = config.virtualisation.podman.enable;
          message = "The Forgejo runner requires Podman.";
        }
      ];

      services.forgejo.settings.actions.ENABLED = true;
      # The runner network is idle between jobs but must survive daily pruning.
      virtualisation.podman.autoPrune.flags = ["--filter=label!=forgejo-runner"];
      # Bridge traffic retains its container source IP when reaching Caddy.
      # Permit this network only on Forgejo, not on every private virtual host.
      services.homelab.caddy.virtualHosts.forgejo.extraAllowedRanges = [subnet];

      sops.secrets.forgejo_adam_small_token.restartUnits = ["forgejo-runner-small.service"];

      services.forgejo-runner.instances.small = {
        enable = true;
        settings = {
          server.connections.default = {
            url = "https://git.${config.services.homelab.domains.zekurio}/";
            uuid = cfg.uuid;
          };
          runner = {
            capacity = 1;
            labels = ["small:docker://docker.io/library/node:22-bookworm"];
          };
          container = {
            inherit network;
            # Podman starts containers outside the runner service's cgroup.
            # Share one budget across the runner, jobs, and service containers.
            options = "--cgroup-parent=${slice} --cpus=2 --memory=4g --memory-swap=4g";
            privileged = false;
            docker_host = "-";
            valid_volumes = [];
          };
        };
        secrets.server.connections.default.token_url =
          config.sops.secrets.forgejo_adam_small_token.path;
      };

      systemd.slices.forgejo-runner = {
        description = "Shared Forgejo runner resource limits";
        sliceConfig = {
          CPUQuota = "200%";
          MemoryMax = "4G";
          MemorySwapMax = "0";
        };
      };

      systemd.services.forgejo-runner-network = {
        description = "Podman network for Forgejo Actions";
        path = [config.virtualisation.podman.package];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = "podman network exists ${network} || podman network create --subnet ${subnet} --label forgejo-runner ${network}";
      };

      systemd.services.forgejo-runner-small = {
        after = ["forgejo.service" "forgejo-runner-network.service"];
        requires = ["forgejo-runner-network.service"];
        wants = ["forgejo.service"];
        serviceConfig.Slice = slice;
      };
    };
  };
}
