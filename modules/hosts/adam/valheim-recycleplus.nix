{
  config,
  lib,
  pkgs,
  ...
}: let
  # RecyclePlus syncs its server settings to clients, so players must install
  # this same version.
  recyclePlus = pkgs.fetchzip {
    name = "recycle-plus-1.3.9";
    url = "https://thunderstore.io/package/download/TastyChickenLegs/RecyclePlus/1.3.9/";
    extension = "zip";
    stripRoot = false;
    hash = "sha256-fQFwXsC/t1gx6grj0csVa1cPg0fKFm46goPd180T2ss=";
  };
in {
  systemd.services.podman-valheim = lib.mkIf config.services.homelab.valheim.enable {
    # The container copies plugins from this persistent directory on startup.
    preStart = lib.mkBefore ''
      ${pkgs.coreutils}/bin/install -D -o 1000 -g 1000 -m 0644 \
        ${recyclePlus}/RecyclePlus.dll \
        /var/lib/valheim/config/valheimplus/plugins/RecyclePlus.dll
    '';
  };
}
