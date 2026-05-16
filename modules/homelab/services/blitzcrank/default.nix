{
  config,
  inputs,
  lib,
  ...
}: let
  cfg = config.services.homelab.blitzcrank;
in {
  imports = [
    inputs.blitzcrank.nixosModules.default
  ];

  options.services.homelab.blitzcrank = {
    enable = lib.mkEnableOption "Blitzcrank Jellyseerr/Jellyfin Discord support agent";
  };

  config = lib.mkIf cfg.enable {
    services.blitzcrank = {
      enable = true;
      environmentFile = config.sops.secrets.blitzcrank_env.path;
    };

    systemd.services.blitzcrank.serviceConfig.SupplementaryGroups = ["share"];

    sops.secrets.blitzcrank_env = {
      owner = "blitzcrank";
      group = "blitzcrank";
      mode = "0400";
    };
  };
}
