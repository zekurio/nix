{osConfig, ...}: let
  hostName = osConfig.networking.hostName;
  identityAgentByHost = {
    adam = "SSH_AUTH_SOCK";
    lilith = "~/.1password/agent.sock";
    tabris = "SSH_AUTH_SOCK";
  };
in {
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks = {
      "*" = {
        compression = true;
        identityAgent = identityAgentByHost.${hostName} or "SSH_AUTH_SOCK";
      };
      "adam" = {
        hostname = "adam.lan";
        user = "zekurio";
        forwardAgent = true;
      };
    };
  };
}
