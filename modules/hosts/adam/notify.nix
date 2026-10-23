{
  flake.modules.nixos.adam = {config, ...}: {
    sops.secrets.ntfy_url = {};

    modules.notify = {
      enable = true;
      urlFile = config.sops.secrets.ntfy_url.path;
      diskDigest.enable = true;
    };
  };
}
