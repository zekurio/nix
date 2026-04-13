{osConfig, ...}: let
  hostName = osConfig.networking.hostName;
  identityAgent =
    if hostName == "lilith"
    then "~/.1password/agent.sock"
    else "SSH_AUTH_SOCK";
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
