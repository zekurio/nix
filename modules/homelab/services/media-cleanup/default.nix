{
  flake.modules.nixos.homelab = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.homelab.mediaCleanup;
    mediaShare = config.services.homelab.mediaShare;
    apps = ["radarr" "sonarr"];
    importHook = pkgs.writeShellApplication {
      name = "clean-media-import";
      runtimeInputs = [pkgs.ffmpeg-headless];
      text = ''
        exec ${lib.getExe pkgs.python3} ${./clean-import.py} "$@"
      '';
    };
    configure = app: let
      service = config.services.${app};
      envName = "${app}-media-cleanup.env";
      apiKeyEnv = "${lib.toUpper app}__AUTH__APIKEY";
    in
      lib.mkIf config.services.homelab.${app}.enable {
        services.${app}.environmentFiles = [config.sops.templates.${envName}.path];
        sops.secrets."${app}_api_key" = {};
        sops.templates.${envName} = {
          content = "${apiKeyEnv}=${config.sops.placeholder."${app}_api_key"}\n";
          owner = service.user;
          group = service.group;
          mode = "0400";
          restartUnits = ["${app}.service"];
        };
        systemd.services.${app} = {
          unitConfig.RequiresMountsFor = [mediaShare.downloadsRoot];
          serviceConfig.TimeoutStartSec = "3min";
          # Configure through the API once it is listening, on every restart.
          # Register cleanup before removing the old Anvil path redirection.
          postStart = ''
            ${lib.getExe pkgs.python3} ${./configure.py} \
              --app ${app} \
              --url ${lib.escapeShellArg config.services.homelab.${app}.baseUrl} \
              --downloads-root ${lib.escapeShellArg mediaShare.downloadsRoot} \
              --import-script ${lib.escapeShellArg (lib.getExe cfg.importHook)}
          '';
        };
      };
  in {
    options.services.homelab.mediaCleanup = {
      enable = lib.mkEnableOption "lossless Radarr and Sonarr import cleanup";
      importHook = lib.mkOption {
        type = lib.types.package;
        readOnly = true;
        default = importHook;
        description = "Import hook that keeps Japanese, German, English and untagged tracks, and cleans metadata without encoding.";
      };
    };
    config = lib.mkIf cfg.enable (lib.mkMerge (
      [
        {
          assertions = [
            {
              assertion = mediaShare.enable && lib.any (app: config.services.homelab.${app}.enable) apps;
              message = "Media cleanup requires mediaShare and Radarr or Sonarr.";
            }
          ];
          environment.systemPackages = [cfg.importHook];
        }
      ]
      ++ map configure apps
    ));
  };
}
