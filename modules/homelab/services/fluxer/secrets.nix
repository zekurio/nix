{
  flake.modules.nixos.homelab = {
    config,
    lib,
    pkgs,
    ...
  }: let
    units = ["fluxer-seaweedfs-init" "podman-fluxer-admin" "podman-fluxer-api" "podman-fluxer-gateway" "podman-fluxer-gifs" "podman-fluxer-gifs-shard" "podman-fluxer-livekit" "podman-fluxer-media-proxy" "podman-fluxer-meilisearch" "podman-fluxer-messages" "podman-fluxer-messages-shard" "fluxer-postgres-password" "podman-fluxer-snowflakes" "podman-fluxer-snowflakes-shard" "podman-fluxer-unfurl" "podman-fluxer-unfurl-shard" "podman-fluxer-users" "podman-fluxer-users-shard" "podman-fluxer-worker"];
    render = pkgs.writeShellScript "fluxer-render-secrets" ''
      exec ${lib.getExe pkgs.python3} ${./render-secrets.py} ${config.sops.secrets.fluxer_env.path} ${./secret-files.json} /run/fluxer-env
    '';
  in {
    config = lib.mkIf config.services.homelab.fluxer.enable {
      sops.secrets.fluxer_env.restartUnits = ["fluxer-secrets.service"] ++ map (name: "${name}.service") units;
      systemd.services =
        lib.genAttrs units (_: {
          requires = ["fluxer-secrets.service"];
          after = ["fluxer-secrets.service"];
          restartTriggers = [render];
        })
        // {
          fluxer-secrets = {
            description = "Prepare Fluxer secret files";
            # sops-nix installs system secrets during activation.
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              RuntimeDirectory = "fluxer-env";
              RuntimeDirectoryMode = "0700";
              ExecStart = render;
            };
          };
        };
    };
  };
}
