{
  flake.modules.nixos.homelab = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.homelab.fluxer;
    initScript = pkgs.writeText "fluxer-seaweedfs-init.sh" ''
      buckets="$FLUXER_S3_BUCKET_CDN $FLUXER_S3_BUCKET_UPLOADS $FLUXER_S3_BUCKET_DOWNLOADS $FLUXER_S3_BUCKET_REPORTS $FLUXER_S3_BUCKET_HARVESTS"; missing="$buckets"; for attempt in $(seq 1 60); do
        if ! nc -z seaweedfs 9333 2>/dev/null; then
          sleep 2;
          continue;
        fi;
        listed=$(echo "s3.bucket.list" | timeout 10 weed shell -master=seaweedfs:9333 2>&1);
        missing="";
        for b in $buckets; do
          echo "$listed" | grep -q "^[[:space:]]*$b[[:space:]]" || missing="''${missing:+$missing }$b";
        done;
        if [ -z "$missing" ]; then
          if ! echo "s3.configure -user=fluxer -access_key=$FLUXER_S3_ACCESS_KEY -secret_key=$FLUXER_S3_SECRET_KEY -actions=Admin,Read,Write,List,Tagging -apply" | timeout 10 weed shell -master=seaweedfs:9333 >/dev/null 2>&1; then
            echo "seaweedfs-init could not configure the S3 identity" >&2;
            exit 1;
          fi;
          echo "buckets ready";
          exit 0;
        fi;
        for b in $missing; do
          echo "s3.bucket.create -name $b" | timeout 10 weed shell -master=seaweedfs:9333 >/dev/null 2>&1;
        done;
        sleep 2;
      done; echo "seaweedfs-init could not verify buckets: $missing" >&2; exit 1;
    '';
  in {
    config = lib.mkIf cfg.enable {
      systemd.services.fluxer-storage = {
        description = "Prepare Fluxer attachment storage";
        path = [config.virtualisation.podman.package];
        unitConfig.RequiresMountsFor = ["/var/lib/fluxer"];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          for volume in fluxer_postgres-data fluxer_meilisearch-data fluxer_nats-data fluxer_valkey-data fluxer_edge-data fluxer_edge-config fluxer_seaweedfs-data; do
            if podman volume exists "$volume"; then
              echo "Remove obsolete Fluxer named volumes before starting the services." >&2
              exit 1
            fi
          done
        '';
      };
      systemd.services.podman-fluxer-seaweedfs = {
        requires = ["fluxer-storage.service"];
        after = ["fluxer-storage.service"];
        unitConfig.RequiresMountsFor = ["/var/lib/fluxer"];
      };
      systemd.services.fluxer-seaweedfs-init = {
        description = "Create Fluxer buckets and S3 identity";
        requires = ["podman-fluxer-seaweedfs.service"];
        after = ["podman-fluxer-seaweedfs.service"];
        partOf = ["fluxer.target"];
        path = [config.virtualisation.podman.package];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          Restart = "on-failure";
          RestartSec = 5;
          TimeoutStartSec = "20min";
        };
        script = ''
          podman run --rm --name fluxer-seaweedfs-init --network fluxer_fluxer \
            --memory=134217728 \
            --env-file /run/fluxer-env/fluxer-seaweedfs-init.env \
            --volume ${initScript}:/init.sh:ro --entrypoint /bin/sh \
            --image-volume=ignore docker.io/chrislusf/seaweedfs:4.34 /init.sh
        '';
        postStop = "podman rm -f --ignore fluxer-seaweedfs-init";
      };
    };
  };
}
