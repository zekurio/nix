{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.services.configarr;

  configarrPkgs =
    pkgs
    // {
      pnpm =
        pkgs.pnpm
        // {
          configHook = pkgs.pnpmConfigHook;
          fetchDeps = pkgs.fetchPnpmDeps;
        };
    };

  configarrPackage =
    (import (inputs.configarr + "/pkgs/nix/package.nix") {
      inherit (configarrPkgs) lib;
      pkgs = configarrPkgs;
    })
    .overrideAttrs (old: {
      nativeBuildInputs = (old.nativeBuildInputs or []) ++ [configarrPkgs.pnpm];
    });

  stateDir = "/var/lib/configarr";
  configFilePath = toString cfg.configFile;
  secretsFilePath = toString cfg.secretsFile;
  etcConfigPath = lib.removePrefix "/etc/" configFilePath;
in {
  options.services.configarr = {
    enable = lib.mkEnableOption "Configarr sync for *arr services";

    package = lib.mkOption {
      type = lib.types.package;
      default = configarrPackage;
      description = "Configarr package to use";
    };

    configFile = lib.mkOption {
      type = lib.types.str;
      default = "/etc/configarr/config.yaml";
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
    assertions = [
      {
        assertion = cfg.configText == "" || lib.hasPrefix "/etc/" configFilePath;
        message = "services.configarr.configFile must be under /etc when configText is set.";
      }
    ];

    users.groups.configarr = {};

    users.users.configarr = {
      isSystemUser = true;
      group = "configarr";
      home = stateDir;
      createHome = true;
      description = "Configarr service account";
    };

    environment.etc = lib.mkIf (cfg.configText != "") {
      "${etcConfigPath}" = {
        text = cfg.configText;
        mode = "0644";
      };
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
