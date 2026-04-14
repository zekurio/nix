{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.services.homelab.configarr;
  stateDir = "/var/lib/configarr";
  reposDir = "${stateDir}/repos";
  runtimeEnvFile = "${stateDir}/configarr.env";
  configFilePath = toString cfg.configFile;
  secretsFilePath = toString cfg.secretsFile;
  configTextFile = pkgs.writeText "configarr-config.yaml" cfg.configText;
in {
  options.services.homelab.configarr = {
    enable = lib.mkEnableOption "Configarr sync for *arr services";

    package = lib.mkOption {
      type = lib.types.package;
      default = inputs.configarr.packages.${pkgs.stdenv.hostPlatform.system}.default;
      description = "Configarr package to use";
    };

    configFile = lib.mkOption {
      type = lib.types.str;
      default = "${stateDir}/config.yaml";
      description = "Path to configarr config file";
    };

    configText = lib.mkOption {
      type = lib.types.lines;
      default = builtins.readFile ./config.yaml;
      description = "Configarr config file contents";
    };

    secretsFile = lib.mkOption {
      type = lib.types.str;
      default = config.sops.secrets.configarr_secrets.path;
      description = "Path to configarr secrets.yml";
    };

    schedule = lib.mkOption {
      type = lib.types.str;
      default = "daily";
      description = "systemd OnCalendar schedule for configarr";
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups.configarr = {};

    users.users.configarr = {
      isSystemUser = true;
      group = "configarr";
      home = stateDir;
      createHome = true;
      description = "Configarr service account";
    };

    sops.secrets.configarr_secrets = {
      owner = "configarr";
      group = "configarr";
      mode = "0400";
    };

    systemd.services.configarr = {
      description = "Configarr sync";
      after = ["network-online.target"];
      wants = ["network-online.target"];
      path = [pkgs.git];
      serviceConfig = {
        Type = "oneshot";
        User = "configarr";
        Group = "configarr";
        WorkingDirectory = stateDir;
        StateDirectory = "configarr";
        ExecStartPre =
          [
            "${pkgs.bash}/bin/bash -euc 'if [ -d \"${reposDir}\" ]; then for repo in \"${reposDir}\"/*; do [ -d \"$repo/.git\" ] || continue; ${pkgs.git}/bin/git -C \"$repo\" reset --hard HEAD; ${pkgs.git}/bin/git -C \"$repo\" clean -fd; done; fi'"
            "${pkgs.bash}/bin/bash -euc 'src=${lib.escapeShellArg secretsFilePath}; dest=${lib.escapeShellArg runtimeEnvFile}; if ${pkgs.gnugrep}/bin/grep -Eq \"^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*:\" \"$src\"; then ${pkgs.gawk}/bin/awk '\\''/^[[:space:]]*#/ || /^[[:space:]]*$/ { next } match($0, /^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*:[[:space:]]*(.*)[[:space:]]*$/, m) { val = m[2]; gsub(/^\\\"|\\\"$/, \"\", val); print m[1] \"=\" val }'\\'' \"$src\" > \"$dest\"; ${pkgs.coreutils}/bin/chmod 0400 \"$dest\"; else ${pkgs.coreutils}/bin/install -D -m 0400 \"$src\" \"$dest\"; fi'"
          ]
          ++ lib.optionals (cfg.configText != "") [
            "${pkgs.coreutils}/bin/install -D -m 0640 ${configTextFile} ${configFilePath}"
          ];
        ExecStart = lib.getExe cfg.package;
        EnvironmentFile = "-${runtimeEnvFile}";
      };
      environment = {
        ROOT_PATH = stateDir;
        CONFIG_LOCATION = configFilePath;
        SECRETS_LOCATION = secretsFilePath;
        LOG_STACKTRACE = "true";
      };
    };

    systemd.timers.configarr = {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = cfg.schedule;
        Persistent = true;
      };
    };
  };
}
