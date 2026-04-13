{
  config,
  osConfig,
  ...
}: let
  desktopEnabled = osConfig.modules.desktop.enable or false;
  identityAgent =
    if desktopEnabled
    then "${config.home.homeDirectory}/.1password/agent.sock"
    else "$SSH_AUTH_SOCK";
in {
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks = {
      "*" = {
        compression = true;
        inherit identityAgent;
      };
      "adam" = {
        hostname = "adam.lan";
        user = "zekurio";
        forwardAgent = true;
      };
    };
  };
}
