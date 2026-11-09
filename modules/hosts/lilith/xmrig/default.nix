{
  config,
  lib,
  pkgs,
  ...
}: let
  username = "zekurio";
  package = pkgs.xmrig-mo;
  jq = lib.getExe pkgs.jq;
  systemctl = "${config.systemd.package}/bin/systemctl";

  # MoneroOcean benchmarks every algorithm and mines whichever pays best,
  # paying out in XMR. xmrig-mo picks one algorithm per process, so CPU and
  # GPU run as separate miners. In one process the CPU's choice, RandomX for
  # XMR, also bound the GPU, which earns next to nothing on it.
  # The address is a Cake Wallet subaddress used only for mining, so the
  # public repo does not expose the main one.
  pool = {
    url = "gulf.moneroocean.stream:20008";
    tls = true;
    user = "89t9rDpSbPPT2SgGX62JTHAVtLmMfkEyrFNS8wyt4DupGPWuPRGFXtxVJmg3KgSRuxTzd7TYTvKnsWzGhJCU2FawQiiMwqH";
    keepalive = true;
    algo = null;
    coin = null;
  };

  miners = {
    cpu = {
      apiPort = 18301;
      settings = {
        cpu = {
          enabled = true;
          huge-pages = true;
        };
        randomx."1gb-pages" = true;
        opencl.enabled = false;
      };
      # No User=, so the CPU miner runs as root: xmrig applies the RandomX
      # MSR mod and reserves huge pages itself, and restores the MSRs when it
      # exits.
      serviceConfig.Nice = 19;
    };
    gpu = {
      apiPort = 18302;
      settings = {
        cpu.enabled = false;
        opencl = {
          enabled = true;
          # xmrig dlopens the loader by bare name, which is not on any
          # library path here. ocl-icd finds the ROCm ICD under
          # /run/opengl-driver.
          loader = "${pkgs.ocl-icd}/lib/libOpenCL.so";
        };
      };
      serviceConfig = {
        DynamicUser = true;
        SupplementaryGroups = ["render" "video"];
        # The thread feeding the GPU needs little CPU time but stalls the
        # card when the CPU miner's 16 threads crowd it out at equal nice.
        Nice = 10;
      };
    };
  };

  # The algorithm calibration takes several minutes and xmrig only keeps it
  # by autosaving its config, so each miner runs from a writable copy. Every
  # start regenerates that copy from Nix and carries over the saved
  # "algo-perf". Delete the state file to force a new calibration after a
  # hardware or driver change.
  prepareConfig = pkgs.writeShellScript "xmrig-prepare-config" ''
    set -eu
    nixConfig=$1
    state=$2
    if [ -f "$state" ] && perf=$(${jq} -ce '."algo-perf" // empty' "$state"); then
      ${jq} --argjson perf "$perf" '. + {"algo-perf": $perf}' "$nixConfig" > "$state.new"
    else
      cp "$nixConfig" "$state.new"
    fi
    # Store files are read-only, and the GPU miner, which is not root, has to
    # autosave into its copy.
    chmod 0600 "$state.new"
    mv "$state.new" "$state"
  '';

  mkService = name: miner: let
    unit = "xmrig-${name}";
    configFile = (pkgs.formats.json {}).generate "${unit}.json" (miner.settings
      // {
        autosave = true;
        colors = false;
        donate-level = 0;
        # Read-only status for the Dux plugin. restricted rejects every
        # request that would change the miner.
        http = {
          enabled = true;
          host = "127.0.0.1";
          port = miner.apiPort;
          restricted = true;
        };
        # MoneroOcean takes the password as the worker name.
        pools = [(pool // {pass = "lilith-${name}";})];
      });
    stateConfig = "/var/lib/${unit}/config.json";
  in
    lib.nameValuePair unit {
      description = "XMRig ${lib.toUpper name} miner for MoneroOcean";
      wantedBy = ["xmrig.target"];
      partOf = ["xmrig.target"];
      wants = ["network-online.target"];
      after = ["network-online.target"];
      serviceConfig =
        {
          StateDirectory = unit;
          # xmrig writes its OpenCL kernel cache to ./.cache.
          WorkingDirectory = "/var/lib/${unit}";
          Environment = "HOME=/var/lib/${unit}";
          ExecStartPre = "${prepareConfig} ${configFile} ${stateConfig}";
          ExecStart = "${lib.getExe package} --config=${stateConfig}";
          Restart = "on-failure";
          RestartSec = 30;
        }
        // miner.serviceConfig;
    };

  units = map (name: "xmrig-${name}.service") (lib.attrNames miners);

  # The miners compete with games for the X3D cache and the GPU, so gamemode
  # stops them for a game's lifetime. Each unit's marker makes the end script
  # restart only what gamemode stopped, so a manual stop sticks. gamemoded's
  # PATH holds only pkexec, so every command needs its store path.
  gameStart = pkgs.writeShellScript "xmrig-gamemode-start" ''
    for unit in ${toString units}; do
      if ${systemctl} is-active --quiet "$unit"; then
        ${pkgs.coreutils}/bin/touch "''${XDG_RUNTIME_DIR:?}/$unit.stopped-by-gamemode"
        ${systemctl} stop "$unit"
      fi
    done
  '';
  gameEnd = pkgs.writeShellScript "xmrig-gamemode-end" ''
    for unit in ${toString units}; do
      marker="''${XDG_RUNTIME_DIR:?}/$unit.stopped-by-gamemode"
      if [ -e "$marker" ]; then
        ${pkgs.coreutils}/bin/rm -f "$marker"
        ${systemctl} start --no-block "$unit"
      fi
    done
  '';

  # The Dux plugin's view of the miners: one line per miner with its unit
  # state and whether gamemode stopped it.
  statusScript = pkgs.writeShellScript "xmrig-status" ''
    for name in ${toString (lib.attrNames miners)}; do
      unit=xmrig-$name.service
      paused=0
      if [ -e "''${XDG_RUNTIME_DIR:?}/$unit.stopped-by-gamemode" ]; then
        paused=1
      fi
      echo "$name $(${systemctl} is-active "$unit") $paused"
    done
  '';

  # Starts or stops one miner, or all of them, for the Dux plugin. A stop
  # also drops gamemode's marker, so the end of a running game does not
  # restart a miner that was turned off during it.
  # One systemctl call per unit. Given several units, systemctl sends them in
  # a single EnqueueUnitJobMany request, which reaches polkit without a unit
  # or a verb, so the rule below cannot allow it and the request is denied.
  controlScript = pkgs.writeShellScript "xmrig-control" ''
    set -eu
    action=$1
    case $action in
      start | stop) ;;
      *)
        echo "usage: xmrig-control start|stop <miner>|all" >&2
        exit 2
        ;;
    esac
    if [ "$2" = all ]; then
      set -- ${toString units}
    else
      set -- "xmrig-$2.service"
    fi
    if [ "$action" = stop ]; then
      for unit; do
        ${pkgs.coreutils}/bin/rm -f "''${XDG_RUNTIME_DIR:?}/$unit.stopped-by-gamemode"
      done
    fi
    status=0
    for unit; do
      ${systemctl} "$action" "$unit" || status=$?
    done
    exit "$status"
  '';

  duxPlugin = pkgs.callPackage ./_dux-plugin.nix {
    settings = {
      miners =
        lib.mapAttrsToList (name: miner: {
          id = name;
          label = lib.toUpper name;
          inherit (miner) apiPort;
        })
        miners;
      status = "${statusScript}";
      control = "${controlScript}";
      poolApi = "https://api.moneroocean.stream";
      address = pool.user;
    };
  };
in {
  hardware.cpu.x86.msr.enable = true;
  hardware.amdgpu.opencl.enable = true;

  # A control center tile, bar pill and popout for the miners. Dux loads it
  # once it is turned on under Settings, Plugins, but the pill and the tile
  # still have to be added by hand in the bar and control center editors.
  # The tile, a right-click on the pill and the popout's "All miners" row
  # each start or stop both miners at once.
  programs.dux-shell.plugins.XmrigControl.src = duxPlugin;

  # Starts and stops both miners at once.
  systemd.targets.xmrig = {
    description = "XMRig miners";
    wantedBy = ["multi-user.target"];
  };
  systemd.services = lib.mapAttrs' mkService miners;

  programs.gamemode.settings.custom = {
    start = ["${gameStart}"];
    end = ["${gameEnd}"];
  };

  # gamemode's scripts run as the session user, which may only start and
  # stop the miners.
  security.polkit.extraConfig = ''
    polkit.addRule(function (action, subject) {
      var units = ${builtins.toJSON (units ++ ["xmrig.target"])};
      if (action.id == "org.freedesktop.systemd1.manage-units" &&
          units.indexOf(action.lookup("unit")) >= 0 &&
          subject.user == "${username}") {
        var verb = action.lookup("verb");
        if (verb == "start" || verb == "stop") {
          return polkit.Result.YES;
        }
      }
    });
  '';
}
