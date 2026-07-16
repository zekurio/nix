{
  flake.modules.homeManager.zekurio = {pkgs, ...}: let
    configDirectory =
      if pkgs.stdenv.hostPlatform.isDarwin
      then "Library/Application Support/feishin"
      else ".config/feishin";
  in {
    # Feishin watches this file and reloads it when its contents change. The
    # custom CSS setting must still be enabled once in Feishin on each system.
    home.file."${configDirectory}/custom.css" = {
      force = true;
      source = ./theme.css;
    };
  };
}
