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
    };
  };
}
