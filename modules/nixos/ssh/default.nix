{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.modules.ssh;

  # Root-owned cache the sync unit refreshes and sshd reads via a %u token.
  # Kept out of the login hot path so a network/CDN outage can never lock every
  # host out at once, and it survives rebuilds (lives under /var/lib).
  keysDir = "/var/lib/authorized-keys";

  syncUnit = "authorized-keys-sync";
in {
  options.modules.ssh = {
    enable =
      lib.mkEnableOption "the unified OpenSSH server with URL-sourced authorized keys"
      // {
        default = true;
      };

    authorizedKeysUrls = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "https://github.com/zekurio.keys"
      ];
      description = ''
        Sources for the currently acceptable SSH public keys. Each must serve
        the keys as raw text, one per line (the format of GitHub's
        `<user>.keys`). Every reachable source is fetched and the union of
        their keys is installed, so any single source can be down without
        losing access. The cache is overwritten only when at least one source
        returns valid keys. Any published key change propagates to every host
        without a rebuild.
      '';
    };

    users = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Login users that accept the keys served at authorizedKeysUrls.";
    };

    refreshInterval = lib.mkOption {
      type = lib.types.str;
      default = "15min";
      description = "Refresh cadence for the key cache (systemd OnUnitActiveSec).";
    };

    fallbackKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = ''
        Break-glass keys baked into the config, applied in addition to the
        fetched set. Leave empty to keep the URL as the single source of truth;
        set it to admit a key on hosts that have never completed a sync yet.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = lib.mkDefault false;
        KbdInteractiveAuthentication = lib.mkDefault false;
        PermitRootLogin = lib.mkDefault "no";
      };
      # Read the synced cache in addition to the NixOS defaults
      # (~/.ssh/authorized_keys and /etc/ssh/authorized_keys.d/%u).
      authorizedKeysFiles = ["${keysDir}/%u"];
    };

    users.users = lib.mkIf (cfg.fallbackKeys != []) (
      lib.genAttrs cfg.users (_: {
        openssh.authorizedKeys.keys = cfg.fallbackKeys;
      })
    );

    systemd.services.${syncUnit} = {
      description = "Sync SSH authorized keys from ${lib.concatStringsSep ", " cfg.authorizedKeysUrls}";
      after = ["network-online.target"];
      wants = ["network-online.target"];
      path = [pkgs.curl pkgs.openssh pkgs.coreutils];
      serviceConfig = {
        Type = "oneshot";
        StateDirectory = "authorized-keys";
        StateDirectoryMode = "0755";
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        NoNewPrivileges = true;
      };
      script = ''
        set -euo pipefail
        tmp="$(mktemp)"
        combined="$(mktemp)"
        merged="$(mktemp)"
        trap 'rm -f "$tmp" "$combined" "$merged"' EXIT

        for url in ${lib.escapeShellArgs cfg.authorizedKeysUrls}; do
          # Skip a source that is unreachable or whose body is not a valid,
          # non-empty key set (HTML error page, captive portal, empty file),
          # so a bad source can never poison the merged set.
          if curl --fail --silent --show-error --location --max-time 20 \
               --retry 3 --retry-delay 2 "$url" -o "$tmp" \
             && ssh-keygen -l -f "$tmp" >/dev/null 2>&1; then
            cat "$tmp" >> "$combined"
            echo "${syncUnit}: fetched keys from $url"
          else
            echo "${syncUnit}: $url unavailable or invalid, skipping" >&2
          fi
        done

        # Union of every reachable source, exact duplicates collapsed.
        sort -u "$combined" > "$merged"

        # Overwrite the cache only when at least one valid key survived, so a
        # total outage (or all-invalid responses) can never cut off access.
        if ! ssh-keygen -l -f "$merged" >/dev/null 2>&1; then
          echo "${syncUnit}: no source returned valid keys; keeping cached keys" >&2
          exit 1
        fi

        ${lib.concatMapStringsSep "\n        " (u: ''install -m 0644 -o root -g root "$merged" "${keysDir}/${u}"'') cfg.users}
        echo "${syncUnit}: installed $(wc -l < "$merged") keys from all reachable sources"
      '';
    };

    systemd.timers.${syncUnit} = {
      description = "Periodically refresh SSH authorized keys from ${lib.concatStringsSep ", " cfg.authorizedKeysUrls}";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "2min";
        OnUnitActiveSec = cfg.refreshInterval;
        Persistent = true;
      };
    };
  };
}
