{
  flake.modules.nixos.adam = {config, ...}: {
    sops.secrets.healthchecks_ping_key = {};

    modules.healthchecks = {
      enable = true;
      pingKeyFile = config.sops.secrets.healthchecks_ping_key.path;
    };
  };
}
