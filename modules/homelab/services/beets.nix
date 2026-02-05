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
    library = "${musicDir}/beets.db";

    plugins = [
      "duplicates"
    ];

    terminal_encoding = "utf-8";

    threaded = true;

    ui = {
      color = true;
    };

    import = {
      write = true;
      copy = true;
      move = false;
      autotag = true;
      bell = true;
      log = "/dev/null";
      quiet = true;
      quiet_fallback = "asis";
    };

    original_date = true;
    per_disc_numbering = true;

    embedart = {
      auto = true;
    };

    paths = {
      default = "$albumartist/($year) $album/$track $title";
      singleton = "$albumartist/($year) $album/$track $title";
      comp = "Compilations/$album/$track $title";
    };

    aunique = {
      keys = [
        "albumartist"
        "album"
      ];
      disambiguators = [
        "albumtype"
        "year"
        "label"
        "catalognum"
        "albumdisambig"
        "releasegroupdisambig"
      ];
      bracket = "[]";
    };

    fetchart = {
      auto = true;
      sources = [
        "filesystem"
        "coverart"
        "itunes"
        "amazon"
        "albumart"
        "fanarttv"
      ];
    };

    lastgenre = {
      auto = true;
      source = "album";
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
    ];
  };
}
