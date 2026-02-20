{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.beets-wrapped;
  musicDir = "/tank/media/music";
  beetsDir = "/var/lib/beets";
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
      default = "$albumartist/($year) $album/$track $title";
      singleton = "$albumartist/($year) $album/$track $title";
      comp = "Compilations/($year) $album/$track $artist - $title";
    };
    ftintitle = {
      auto = true;
      drop = false;
    };
    lyrics = {
      auto = true;
    };
  };

  beetsConfigFile = settingsFormat.generate "beets.yaml" beetsConfig;

  beetWrapped = pkgs.writeScriptBin "beet-wrapped" ''
    sudo -u share BEETSDIR=${beetsDir} ${lib.getExe pkgs.beets} -c ${beetsConfigFile} "$@"
  '';
in {
  options.services.beets-wrapped = {
    enable = lib.mkEnableOption "Beets music organizer";

    configFile = lib.mkOption {
      type = lib.types.path;
      readOnly = true;
      description = "Path to the generated beets configuration file.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.beets-wrapped.configFile = beetsConfigFile;

    environment.systemPackages = [beetWrapped];

    systemd.tmpfiles.rules = [
      "d ${beetsDir} 2775 share share -"
      # Default ACL: new files inherit group rw so slskd (in share group) can write beets.db
      "a+ ${beetsDir} - - - - default:group::rwx"
    ];
  };
}
