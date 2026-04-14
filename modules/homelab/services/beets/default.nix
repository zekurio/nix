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
      default = "$primary_artist_dir/($year) $album/$track $title";
      singleton = "$primary_artist_dir/($year) $album/$track $title";
      comp = "Compilations/($year) $album/$track $artist_dir - $title";
    };
    item_fields.primary_artist = ''
      import re

      name = (albumartist or artist or "").strip()
      if not name:
          return "Unknown Artist"

      # Keep full credits in tags, but file albums under the first credited artist.
      primary_artist = re.split(
          r"\s+(?:feat\.?|featuring|ft\.?|with|vs\.?|and|x)\s+|\s*&\s*|,\s*|;\s*",
          name,
          maxsplit=1,
      )[0].strip()
      return primary_artist or name
    '';
    item_fields.primary_artist_dir = ''
      import re

      name = (albumartist or artist or "").strip()
      if not name:
          return "Unknown Artist"

      primary_artist = re.split(
          r"\s+(?:feat\.?|featuring|ft\.?|with|vs\.?|and|x)\s+|\s*&\s*|,\s*|;\s*",
          name,
          maxsplit=1,
      )[0].strip()

      # Preserve artist names in tags while normalizing path separators for the filesystem.
      return re.sub(r"[\\/]+", "-", primary_artist or name).strip() or "Unknown Artist"
    '';
    item_fields.artist_dir = ''
      import re

      name = (artist or "").strip()
      if not name:
          return "Unknown Artist"

      return re.sub(r"[\\/]+", "-", name).strip() or "Unknown Artist"
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
    exec /run/wrappers/bin/sudo -u ${shareUser} \
      BEETSDIR=${beetsDir} \
      ${lib.getExe pkgs.beets} -c ${beetsConfigFile} "$@"
  '';

  beetImportWrapped = pkgs.writeShellScriptBin "beet-import-wrapped" ''
    set -eu

    export BEETSDIR=${beetsDir}

    if [ "$(${pkgs.coreutils}/bin/id -un)" = "${shareUser}" ]; then
      exec ${lib.getExe pkgs.beets} -c ${beetsConfigFile} import -q "$@"
    fi

    if [ "$(${pkgs.coreutils}/bin/id -u)" -eq 0 ]; then
      exec ${pkgs.util-linux}/bin/runuser -u ${shareUser} -- \
        ${lib.getExe pkgs.beets} -c ${beetsConfigFile} import -q "$@"
    fi

    exec /run/wrappers/bin/sudo -u ${shareUser} \
      ${pkgs.coreutils}/bin/env BEETSDIR=${beetsDir} \
      ${lib.getExe pkgs.beets} -c ${beetsConfigFile} import -q "$@"
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
      "a+ ${beetsDir} - - - - g:share:rwx"
      "A+ ${beetsDir} - - - - g:share:rwx"
      "a+ ${beetsDir} - - - - m::rwx"
      "A+ ${beetsDir} - - - - m::rwx"
    ];
  };
}
