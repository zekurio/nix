{
  flake.modules.nixos.homelab = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.homelab.cleanTrackNames;
    cleanTrackNames = pkgs.writeShellApplication {
      name = "clean-track-names";
      runtimeInputs = [pkgs.mkvtoolnix];
      text = ''
        exec ${lib.getExe pkgs.python3} ${./clean-track-names.py} "$@"
      '';
    };
    scriptPath = "/run/current-system/sw/bin/clean-track-names";
    mkProvisioner = {
      apiKeyFile,
      app,
      baseUrl,
    }: {
      description = "Configure ${app} track-name import script";
      after = [
        "${app}.service"
        "sops-nix.service"
      ];
      partOf = ["${app}.service"];
      wants = ["${app}.service"];
      wantedBy = ["multi-user.target"];

      path = with pkgs; [
        coreutils
        curl
        jq
      ];

      script = ''
        api_url=${lib.escapeShellArg "${baseUrl}/api/v3"}
        header_file="$RUNTIME_DIRECTORY/api-header"
        script_path=${lib.escapeShellArg scriptPath}
        trap 'rm -f "$header_file"' EXIT

        api_key=$(<${lib.escapeShellArg apiKeyFile})
        printf 'X-Api-Key: %s\nContent-Type: application/json\n' "$api_key" > "$header_file"
        unset api_key

        ready=
        current=
        for _ in $(seq 1 60); do
          if current=$(curl --fail --silent --header @"$header_file" "$api_url/config/mediamanagement"); then
            ready=1
            break
          fi
          sleep 1
        done

        if [[ -z "$ready" ]]; then
          curl --fail --silent --show-error --header @"$header_file" "$api_url/config/mediamanagement" >/dev/null
          exit 1
        fi

        if ! jq --exit-status --arg path "$script_path" \
          '.useScriptImport == true and .scriptImportPath == $path' \
          <<< "$current" >/dev/null; then
          updated=$(jq --arg path "$script_path" \
            '.useScriptImport = true | .scriptImportPath = $path' \
            <<< "$current")
          curl --fail --silent --show-error \
            --header @"$header_file" \
            --request PUT \
            --data-binary "$updated" \
            "$api_url/config/mediamanagement" >/dev/null
        fi

        # The import script replaces the old post-import Connect hooks. Delete
        # only Custom Script entries that point at this exact executable.
        notifications=$(curl --fail --silent --show-error \
          --header @"$header_file" \
          "$api_url/notification")
        while IFS= read -r notification_id; do
          [[ -z "$notification_id" ]] && continue
          curl --fail --silent --show-error \
            --header @"$header_file" \
            --request DELETE \
            "$api_url/notification/$notification_id" >/dev/null
        done < <(jq --raw-output --arg path "$script_path" '
          .[]
          | select(.implementation == "CustomScript")
          | select(any(.fields[]?; .name == "path" and .value == $path))
          | .id
        ' <<< "$notifications")
      '';

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        Restart = "on-failure";
        RestartSec = "10s";
        RuntimeDirectory = "clean-track-names-${app}";
        UMask = "0077";

        CapabilityBoundingSet = "";
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
        ];
      };
    };
  in {
    options.services.homelab.cleanTrackNames.enable =
      lib.mkEnableOption "the Sonarr/Radarr MKV track-name import script";

    config = lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = config.services.homelab.radarr.enable || config.services.homelab.sonarr.enable;
          message = "services.homelab.cleanTrackNames requires Radarr or Sonarr.";
        }
      ];

      # Arr's media-management import-script setting uses this stable path; the
      # wrapper adds MKVToolNix to PATH without installing it globally.
      environment.systemPackages = [cleanTrackNames];

      sops.secrets = lib.mkMerge [
        (lib.mkIf config.services.homelab.sonarr.enable {
          sonarr_api_key = {};
        })
        (lib.mkIf config.services.homelab.radarr.enable {
          radarr_api_key = {};
        })
      ];

      systemd.services = lib.mkMerge [
        (lib.mkIf config.services.homelab.sonarr.enable {
          "clean-track-names-sonarr" = mkProvisioner {
            app = "sonarr";
            inherit (config.services.homelab.sonarr) baseUrl;
            apiKeyFile = config.sops.secrets.sonarr_api_key.path;
          };
        })
        (lib.mkIf config.services.homelab.radarr.enable {
          "clean-track-names-radarr" = mkProvisioner {
            app = "radarr";
            inherit (config.services.homelab.radarr) baseUrl;
            apiKeyFile = config.sops.secrets.radarr_api_key.path;
          };
        })
      ];
    };
  };
}
