{lib, ...}: {
  options.profiles.packages.cli.enable =
    lib.mkEnableOption "day-to-day CLI/sysadmin packages"
    // {
      default = true;
    };

  config = {
    home.sessionPath = [
      "$HOME/.local/bin"
    ];
  };
}
