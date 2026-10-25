{
  flake.modules.nixos.adam = {config, ...}: {
    sops.secrets = {
      healthchecks_ping_key = {};
      healthchecks_api_key = {};
    };

    modules.healthchecks = {
      enable = true;
      pingKeyFile = config.sops.secrets.healthchecks_ping_key.path;
      apiKeyFile = config.sops.secrets.healthchecks_api_key.path;
    };
  };
}
