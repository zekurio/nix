{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.modules.hdr;
  hyprctl = "${config.programs.hyprland.package}/bin/hyprctl";

  # HDR is on while this file exists. Outside the store, so the choice
  # survives rebuilds, and outside DMS's fragments, which it rewrites.
  stateFile = "${config.users.users.zekurio.home}/.local/state/hyprland/hdr";

  # Lua literals for the outputs' monitor fields. JSON strings and numbers
  # read the same in Lua.
  toLua = value:
    if lib.isAttrs value
    then "{ ${lib.concatMapStringsSep ", " (name: "[${builtins.toJSON name}] = ${toLua value.${name}}") (lib.attrNames value)} }"
    else builtins.toJSON value;

  hdrMode = pkgs.writeShellScriptBin "hdr-mode" ''
    set -eu
    state=${lib.escapeShellArg stateFile}
    enable() {
      ${pkgs.coreutils}/bin/mkdir -p "''${state%/*}"
      ${pkgs.coreutils}/bin/touch "$state"
    }
    case ''${1:-status} in
      status)
        if [ -e "$state" ]; then echo on; else echo off; fi
        exit 0
        ;;
      on) enable ;;
      off) ${pkgs.coreutils}/bin/rm -f "$state" ;;
      toggle)
        if [ -e "$state" ]; then
          ${pkgs.coreutils}/bin/rm -f "$state"
        else
          enable
        fi
        ;;
      *)
        echo "usage: hdr-mode [status|on|off|toggle]" >&2
        exit 2
        ;;
    esac
    # A reload runs hyprland.lua again, which reads the state file.
    exec ${hyprctl} reload
  '';

  duxPlugin = pkgs.callPackage ./_dux-plugin.nix {
    # Through the system profile, as in xmrig/default.nix: the shell keeps
    # this path until it restarts.
    settings.command = "/run/current-system/sw/bin/hdr-mode";
  };
in {
  options.modules.hdr.outputs = lib.mkOption {
    type = with lib.types;
      attrsOf (submodule {
        options = {
          sdr = lib.mkOption {
            type = attrsOf (oneOf [str int float]);
            default = {};
            description = "hl.monitor fields for this output while HDR is off.";
          };
          hdr = lib.mkOption {
            type = attrsOf (oneOf [str int float]);
            description = "hl.monitor fields for this output while HDR is on.";
          };
        };
      });
    default = {};
    description = ''
      Monitor fields the HDR toggle merges into DMS's rules, keyed by the
      rule's output string.
    '';
  };

  config = {
    # DMS owns dms/outputs.lua and drops fields it has no setting for. Its
    # rules pass through this wrapper, which adds the fields for the current
    # mode, so DMS's display settings keep working in both. It has to be in
    # place before DMS's requires call hl.monitor.
    modules.hyprland.preConfig = ''
      do
        local outputs = ${toLua cfg.outputs}
        local state = io.open(${builtins.toJSON stateFile}, "r")
        local mode = state and "hdr" or "sdr"
        if state then state:close() end
        local monitor = hl.monitor
        hl.monitor = function(rule)
          local fields = outputs[rule.output]
          if fields then
            local merged = {}
            for key, value in pairs(rule) do merged[key] = value end
            for key, value in pairs(fields[mode]) do merged[key] = value end
            rule = merged
          end
          return monitor(rule)
        end
      end
    '';

    environment.systemPackages = [hdrMode];

    # A control center tile and bar pill that switch the desktop between SDR
    # and HDR. Dux loads it once it is turned on under Settings, Plugins;
    # the pill and tile still have to be added in the bar and control center
    # editors.
    programs.dux-shell.plugins.HdrToggle.src = duxPlugin;
  };
}
