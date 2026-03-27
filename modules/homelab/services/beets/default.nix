{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.homelab.beets;
  musicDir = "/tank/media/music";
  beetsDir = "/var/lib/beets";
  shareUser = "share";
  settingsFormat = pkgs.formats.yaml {};

  beetsConfig = {
    directory = musicDir;
    library = "${beetsDir}/beets.db";
    plugins = [
      "musicbrainz"
      "duplicates"
      "ftintitle"
      "fetchart"
      "embedart"
      "inline"
      "lyrics"
    ];
    import = {
      write = true;
      autotag = true;
      copy = false;
      move = true;
      quiet = true;
      quiet_fallback = "asis";
      log = "${beetsDir}/import.log";
    };
    paths = {
      default = "$primary_artist/($year) $album/$track $title";
      singleton = "$primary_artist/($year) $album/$track $title";
      comp = "Compilations/($year) $album/$track $artist - $title";
    };
    inline.item_fields.primary_artist = ''
      import re

      name = (albumartist or artist or "").strip()
      if not name:
          return "Unknown Artist"

      # Keep full credits in tags, but file albums under the first credited artist.
      primary_artist = re.split(
          r"\s+(?:feat\.?|featuring|ft\.?|with|vs\.?|and|x)\s+|\s*&\s*|,\s*|;\s*|/\s*",
          name,
          maxsplit=1,
      )[0].strip()
      return primary_artist or name
    '';
    ftintitle = {
      auto = true;
      drop = false;
    };
    lyrics = {
      auto = true;
    };
  };

  beetsConfigFile = settingsFormat.generate "beets.yaml" beetsConfig;

  beetWrapped = pkgs.writeShellScriptBin "beet-wrapped" ''
    exec ${pkgs.sudo}/bin/sudo -u ${shareUser} \
      BEETSDIR=${beetsDir} \
      ${lib.getExe pkgs.beets} -c ${beetsConfigFile} "$@"
  '';

  beetImportWrapped = pkgs.writeShellScriptBin "beet-import-wrapped" ''
    exec ${pkgs.util-linux}/bin/runuser -u ${shareUser} -- \
      ${pkgs.bash}/bin/bash -lc \
      'export BEETSDIR='"${beetsDir}"'; exec '"${lib.getExe pkgs.beets}"' -c '"${beetsConfigFile}"' import -q "$@"' \
      -- "$@"
  '';
in {
  options.services.homelab.beets = {
    enable = lib.mkEnableOption "Beets music organizer";

    configFile = lib.mkOption {
      type = lib.types.path;
      readOnly = true;
      description = "Path to the generated beets configuration file.";
    };

    importCommand = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to the generated non-interactive beets import wrapper.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.homelab.beets.configFile = beetsConfigFile;
    services.homelab.beets.importCommand = "${beetImportWrapped}/bin/beet-import-wrapped";

    environment.systemPackages = [beetWrapped];

    systemd.tmpfiles.rules = [
      "d ${beetsDir} 2775 share share -"
      # Default ACL: new files inherit group rw so slskd (in share group) can write beets.db
      "a+ ${beetsDir} - - - - default:group::rwx"
    ];
  };
}
