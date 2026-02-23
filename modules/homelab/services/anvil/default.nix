{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.services.anvil-wrapped;
  stateDir = "/var/lib/anvil";
  configFilePath = toString cfg.configFile;
  secretsFilePath = toString cfg.secretsFile;
  configTextFile = pkgs.writeText "anvil-config.yaml" cfg.configText;
in {
  imports = [
    inputs.anvil.nixosModules.default
  ];

  options.services.anvil-wrapped = {
    enable = lib.mkEnableOption "Anvil media orchestration with local config and SOPS secrets";

    configFile = lib.mkOption {
      type = lib.types.str;
      default = "${stateDir}/config.yaml";
      description = "Path to anvil config file";
    };

    configText = lib.mkOption {
      type = lib.types.lines;
      default = builtins.readFile ./config.yaml;
      description = "Anvil config file contents";
    };

    secretsFile = lib.mkOption {
      type = lib.types.str;
      default = config.sops.secrets.anvil_secrets.path;
      description = "Path to anvil secrets YAML";
    };
  };

  config = lib.mkIf cfg.enable {
    sops.secrets.anvil_secrets = {
      owner = "anvil";
      group = "anvil";
      mode = "0400";
    };

    services.anvil = {
      enable = true;
      configFile = configFilePath;
      secretsFile = secretsFilePath;
      openFirewall = true;
      firewallPort = 46845;
      supplementaryGroups = ["share"];
      tempDir = "/var/tmp/anvil";
      dbPath = "${stateDir}/anvil.db";
    };

    systemd.services.anvil = {
      after = ["sops-install-secrets.service"];
      wants = ["sops-install-secrets.service"];
      serviceConfig = {
        PermissionsStartOnly = true;
        ExecStartPre = [
          "${pkgs.coreutils}/bin/install -D -m 0640 -o ${config.services.anvil.user} -g ${config.services.anvil.group} ${configTextFile} ${configFilePath}"
        ];
      };
    };
  };
}
