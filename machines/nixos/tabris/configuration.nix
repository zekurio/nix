{...}: {
  imports = [
    ../default.nix
  ];

  networking.hostName = "tabris";

  modules.virtualization.enable = true;

  wsl = {
    enable = true;
    defaultUser = "zekurio";
  };

  system.stateVersion = "25.05";
}
