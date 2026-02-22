{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.services.configarr;
  stateDir = "/var/lib/configarr";
  configFilePath = toString cfg.configFile;
  secretsFilePath = toString cfg.secretsFile;
  configTextFile = pkgs.writeText "configarr-config.yaml" cfg.configText;
in {
  options.services.configarr = {
    enable = lib.mkEnableOption "Configarr sync for *arr services";

    package = lib.mkOption {
      type = lib.types.package;
      default = inputs.configarr.packages.${pkgs.system}.default;
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
        PermissionsStartOnly = true;
        WorkingDirectory = stateDir;
        StateDirectory = "configarr";
        ExecStartPre = lib.optionals (cfg.configText != "") [
          "${pkgs.coreutils}/bin/install -D -m 0640 -o configarr -g configarr ${configTextFile} ${configFilePath}"
        ];
        ExecStart = lib.getExe cfg.package;
      };
      environment = {
        ROOT_PATH = stateDir;
        CONFIG_LOCATION = configFilePath;
        SECRETS_LOCATION = secretsFilePath;
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
