{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (config.programs) dux-shell hyprland;
  inherit (config.home-manager.users.zekurio.home) pointerCursor;
  inherit (config.services.xserver) xkb;
  cfg = config.modules.hyprland;

  # What `dms setup` deploys, taken from the installed version's source.
  embedded = "${dux-shell.package.src}/core/internal/config/embedded";

  # The stock fragments under ~/.config/hypr/dms, which DMS owns. outputs.lua
  # starts from the monitors in monitors.nix instead of DMS's catch-all.
  fragments = pkgs.runCommand "dux-hyprland-fragments" {} ''
    mkdir $out
    for name in binds-user colors cursor input layout windowrules; do
      cp ${embedded}/hypr-$name.lua $out/$name.lua
    done
    substitute ${embedded}/hypr-binds.lua $out/binds.lua \
      --replace-fail '{{TERMINAL_COMMAND}}' kitty
    {
      echo "-- Seeded from modules/hosts/lilith/monitors.nix. DMS's display settings rewrite this file."
      echo
      cat ${pkgs.writeText "outputs.lua" cfg.outputs}
    } > $out/outputs.lua
  '';

  lua = builtins.toJSON;

  # DMS's hyprland.lua. Its startup block imports the environment into
  # systemd and starts hyprland-session.target, which starts dms.service.
  hyprlandConfig =
    pkgs.runCommand "hyprland.lua" {
      nativeBuildInputs = [hyprland.package];
    } ''
      # DMS only writes dms/cursor.lua when its cursor settings change, so
      # its "System Default" never reaches Hyprland. Set the cursor ahead of
      # the requires, where a cursor picked in DMS's settings still wins.
      {
        echo 'hl.env("XCURSOR_THEME", ${lua pointerCursor.name})'
        echo 'hl.env("XCURSOR_SIZE", ${lua (toString pointerCursor.size)})'
        echo
        cat ${pkgs.writeText "hyprland-pre.lua" cfg.preConfig}
        echo
        cat ${embedded}/hyprland.lua
      } > stock.lua

      # Hyprland does not read the keymap from locale1 the way niri did, and
      # NixOS sets no XKB_DEFAULT_LAYOUT. DMS's keyboard settings write
      # dms/input.lua, which is required later and still wins.
      #
      # DMS's startup block runs the environment import and the target start
      # as two concurrent commands. Hyprland imports WAYLAND_DISPLAY into
      # systemd itself, so dms.service can start with it but without
      # XDG_SESSION_TYPE. Electron and Chromium apps launched from DMS then
      # pick XWayland, where Hyprland rounds, blurs and shadows their
      # override-redirect menus. Starting the target only after an import has
      # finished closes the race; the first import is repeated, harmlessly.
      substitute stock.lua $out \
        --replace-fail 'hl.exec_cmd("systemctl --user start hyprland-session.target")' \
          'hl.exec_cmd("dbus-update-activation-environment --systemd --all && systemctl --user start hyprland-session.target")' \
        --replace-fail '-- empty inherits XKB_DEFAULT_LAYOUT (libxkbcommon), falls back to "us"' \
          "-- From NixOS's services.xserver.xkb" \
        --replace-fail 'kb_layout = "",' \
          ${lib.escapeShellArg "kb_layout = ${lua xkb.layout}, kb_variant = ${lua xkb.variant}, kb_options = ${lua xkb.options},"}

      # After DMS's requires, so these binds and window rules override its
      # own.
      cat ${pkgs.writeText "hyprland-extra.lua" cfg.extraConfig} >> $out

      # Catch options and fields that this Hyprland no longer accepts.
      mkdir -p check/dms
      cp $out check/hyprland.lua
      cp ${fragments}/* check/dms/
      HOME=$PWD XDG_RUNTIME_DIR=$PWD Hyprland --verify-config -c check/hyprland.lua > check.log 2>&1 || {
        cat check.log
        exit 1
      }
    '';
in {
  # DMS owns the fragments under ~/.config/hypr/dms and rewrites them from
  # its settings pages, so Hyprland configuration kept in Nix goes here.
  options.modules.hyprland = {
    preConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Lua placed ahead of DMS's requires, which runs before its fragments.";
    };
    extraConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Lua appended to hyprland.lua after DMS's requires.";
    };
    outputs = lib.mkOption {
      type = lib.types.lines;
      description = ''
        hl.monitor calls that seed DMS's dms/outputs.lua and configure the
        greeter's Hyprland.
      '';
    };
  };

  config = {
    programs = {
      dux-shell.enable = true;
      # File search for the DMS launcher.
      dux-search.enable = true;
      dux-files.enable = true;
    };

    home-manager.users.zekurio = {
      config,
      lib,
      ...
    }: {
      xdg.configFile."hypr/hyprland.lua".source = hyprlandConfig;

      # DMS's settings pages rewrite the fragments, so they are copied once
      # instead of linked. DMS creates some missing ones empty, and Hyprland
      # stops at a require it cannot find, so empty files count as missing.
      # A changed monitors.nix therefore only reaches outputs.lua after the
      # file is deleted.
      home.activation.duxHyprlandFragments = lib.hm.dag.entryAfter ["writeBoundary"] ''
        dir=${lib.escapeShellArg "${config.xdg.configHome}/hypr/dms"}
        run mkdir -p "$dir"
        for file in ${fragments}/*; do
          target="$dir/''${file##*/}"
          if [ ! -s "$target" ]; then
            run install -m 644 "$file" "$target"
          fi
        done
      '';
    };
  };
}
