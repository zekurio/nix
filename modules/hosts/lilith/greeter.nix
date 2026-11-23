{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.displayManager.dux-greeter;
  inherit (config.home-manager.users.zekurio.home) pointerCursor;
  inherit (config.services.xserver) xkb;
  lua = builtins.toJSON;
  cache = "/var/lib/dms-greeter";
  jq = lib.getExe pkgs.jq;
  localAssets = pkgs.writeText "greeter-local-assets.jq" ''
    def cached:
      type == "string" and (length == 0 or test("^/var/lib/dms-greeter/[^/]+$"));
    with_entries(
      if (.key | test("^wallpaperPath(Light|Dark)?$|^customThemeFile$")) then
        select(.value == null or (.value | cached))
      elif (.key | test("^monitorWallpapers(Light|Dark)?$")) and .value != null then
        .value |= with_entries(select(.value | cached))
      else . end
    )
  '';
  prepareCache = pkgs.writeShellScript "greeter-prepare-cache" ''
    set -eu
    [ -d "${cache}" ] || exit 0
    cd ${cache}
    # Old versions could leave source paths in the cached JSON after a failed copy.
    for name in session.json settings.json; do
      if [ -f "$name" ]; then
        tmp=$(mktemp ".$name.XXXXXX")
        if ${jq} -f ${localAssets} "$name" > "$tmp"; then
          chown dms-greeter:dms-greeter "$tmp"
          mv -fT "$tmp" "$name"
        else
          rm -f "$tmp" "$name"
        fi
      fi
    done
  '';
  upstreamCopy = config.systemd.services.greetd.preStart;
  stagedCopy = lib.replaceStrings ["cd ${cache}"] ["cd \"$stage\""] upstreamCopy;
in {
  services.displayManager.dux-greeter = {
    enable = true;
    compositor = {
      name = "hyprland";
      # Replaces the greeter's built-in Hyprland config. Keep its monitor
      # rules in sync with the session so both request the same mode.
      customConfig = ''
        hl.env("DMS_RUN_GREETER", "1")
        -- The greeter runs as its own user and cannot use the desktop's ~/.icons.
        hl.env("XCURSOR_PATH", ${lua "${pointerCursor.package}/share/icons"})
        hl.env("XCURSOR_THEME", ${lua pointerCursor.name})
        hl.env("XCURSOR_SIZE", ${lua (toString pointerCursor.size)})
        hl.config({
            cursor = { enable_hyprcursor = false },
            misc = { disable_hyprland_logo = true, disable_splash_rendering = true },
            input = { kb_layout = ${lua xkb.layout}, kb_variant = ${lua xkb.variant}, kb_options = ${lua xkb.options}, numlock_by_default = true },
        })
        ${config.modules.hyprland.outputs}
      '';
    };
    # The background sync reads the desktop's settings from here.
    configHome = config.users.users.zekurio.home;
  };

  assertions = [
    {
      assertion = stagedCopy != upstreamCopy;
      message = "The Dux greeter copy script changed its cache directory. Update modules/hosts/lilith/greeter.nix.";
    }
  ];

  systemd = {
    # The upstream preStart script probes desktop assets, which can be on NFS.
    services.greetd.serviceConfig.ExecStartPre = lib.mkForce [prepareCache];
    services.dux-greeter-sync = {
      description = "Copy the Dux Shell theme to the greeter";
      serviceConfig = {
        Type = "oneshot";
        TimeoutStartSec = "20s";
      };
      script = ''
        set -eu
        stage=$(mktemp -d ${cache}/.sync.XXXXXX)
        trap 'rm -rf -- "$stage"' EXIT
        (
          set -e -o pipefail
          ${stagedCopy}
        )

        # Leave the last good cache in place if an asset was unavailable.
        for name in session.json settings.json; do
          if [ -f "$stage/$name" ]; then
            ${jq} -f ${localAssets} "$stage/$name" > "$stage/.filtered"
            if ! ${jq} -e --slurp '.[0] == .[1]' "$stage/$name" "$stage/.filtered" >/dev/null; then
              exit 0
            fi
          fi
        done
        for file in "$stage"/*; do
          name=$(basename "$file")
          case "$name" in
            session.json|settings.json) continue ;;
          esac
          [ ! -f "$file" ] || mv -fT "$file" "${cache}/$name"
        done
        for name in session.json settings.json; do
          [ ! -f "$stage/$name" ] || mv -fT "$stage/$name" "${cache}/$name"
        done
      '';
    };
    timers.dux-greeter-sync = {
      wantedBy = ["timers.target"];
      timerConfig.OnBootSec = "30s";
    };
    paths.dux-greeter-sync = {
      wantedBy = ["multi-user.target"];
      # Path units watch the parent directory, so files that do not exist
      # yet, such as the legacy DankMaterialShell ones, are fine.
      pathConfig.PathChanged = cfg.configFiles;
    };
  };
}
