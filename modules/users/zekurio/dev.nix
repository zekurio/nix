{lib, ...}: {
  options.profiles.dev.enable =
    lib.mkEnableOption "development packages"
    // {
      default = true;
    };
}
