{lib, ...}: let
  inherit (lib) mkAfter mkDefault;
  mainUser = "zekurio";
in {
  imports = [
    ../../../desktop
    ../../../gaming
  ];

  networking.firewall.enable = mkDefault true;

  modules = {
    desktop.enable = mkDefault true;
    gaming.enable = mkDefault true;
    virtualization.enable = mkDefault true;
  };

  home-manager.users.${mainUser} = {
    profiles.desktop.enable = mkDefault true;
    profiles.dev.enable = mkDefault true;
  };

  hardware = {
    graphics = {
      enable = mkDefault true;
      enable32Bit = mkDefault true;
    };
    cpu.amd.updateMicrocode = mkDefault true;
  };

  environment.sessionVariables.LIBVA_DRIVER_NAME = mkDefault "radeonsi";

  services.fwupd.enable = mkDefault true;

  users.users.${mainUser}.extraGroups = mkAfter ["networkmanager"];

  console.keyMap = mkDefault "de";
}
