{...}: {
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks = {
      "*".compression = true;
      "adam" = {
        hostname = "adam.lan";
        user = "zekurio";
        forwardAgent = true;
      };
      "lilith" = {
        hostname = "46.224.128.128";
        user = "zekurio";
        forwardAgent = true;
      };
    };
  };
}
