{
  flake.modules.nixos.homelab = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.homelab.cleanTrackNames;
    cleanTrackNames = pkgs.writeShellApplication {
      name = "clean-track-names";
      runtimeInputs = [pkgs.mkvtoolnix];
      text = ''
        exec ${lib.getExe pkgs.python3} ${./clean-track-names.py} "$@"
      '';
    };
  in {
    options.services.homelab.cleanTrackNames.enable =
      lib.mkEnableOption "the Sonarr/Radarr MKV track-name cleanup hook";

    config = lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = config.services.homelab.radarr.enable || config.services.homelab.sonarr.enable;
          message = "services.homelab.cleanTrackNames requires Radarr or Sonarr.";
        }
      ];

      # Arr custom-script connections use this stable path; the wrapper adds
      # MKVToolNix to PATH without installing it globally as a separate package.
      environment.systemPackages = [cleanTrackNames];
    };
  };
}
