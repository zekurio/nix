{
  config,
  lib,
  pkgs,
  ...
}: let
  # Jötunn rejects clients whose Jötunn differs by any version part, so this
  # tracks the latest release that mod managers install.
  jotunn = pkgs.fetchurl {
    url = "https://github.com/Valheim-Modding/Jotunn/releases/download/v2.30.2/Jotunn.dll";
    hash = "sha256-aJFuwSWoe8Gb1X4NiQQRYW0VUYrF6AnxDRSp4COJC2A=";
  };
  planBuild = pkgs.fetchzip {
    name = "planbuild-0.20.0";
    url = "https://thunderstore.io/package/download/MathiasDecrock/PlanBuild/0.20.0/";
    extension = "zip";
    stripRoot = false;
    hash = "sha256-mazTb+pA0jV/ejTOZONv1LkUUSnoJFGiDYFOdU9uLrk=";
  };
  # The relative default search path scans the whole server install. Keep
  # uploaded blueprints in the persistent config volume instead.
  settings = pkgs.writeText "marcopogo.PlanBuild.cfg" ''
    [Server Settings]
    Allow direct build = true
    Allow terrain tools = true
    Allow serverside blueprints = true

    [Directories]
    Search directory = /config/valheimplus/PlanBuild/blueprints
    Save directory = /config/valheimplus/PlanBuild/blueprints
  '';
  plugins = "/var/lib/valheim/config/valheimplus/plugins";
in {
  systemd.services.podman-valheim = lib.mkIf config.services.homelab.valheim.enable {
    # Replace the plugin directories so files dropped by an update do not
    # linger in the persistent directory the container copies from.
    preStart = lib.mkBefore ''
      ${pkgs.coreutils}/bin/rm -rf ${plugins}/Jotunn ${plugins}/PlanBuild
      ${pkgs.coreutils}/bin/install -D -o 1000 -g 1000 -m 0644 \
        ${jotunn} ${plugins}/Jotunn/Jotunn.dll
      ${pkgs.coreutils}/bin/cp -rT --no-preserve=mode,ownership \
        ${planBuild}/plugins/PlanBuild ${plugins}/PlanBuild
      ${pkgs.coreutils}/bin/chown -R 1000:1000 ${plugins}/PlanBuild
      ${pkgs.coreutils}/bin/install -D -o 1000 -g 1000 -m 0644 ${settings} \
        /var/lib/valheim/config/valheimplus/marcopogo.PlanBuild.cfg
    '';
  };
}
