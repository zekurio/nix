{pkgs, ...}: {
  imports = [
    ./disko.nix
  ];

  modules.desktop = {
    enable = true;
    mainUser = "zekurio";
  };

  modules.virtualization.enable = true;

  boot = {
    loader = {
      timeout = 1;
      efi.canTouchEfiVariables = true;
      systemd-boot.enable = true;
    };
  };

  console.keyMap = "de";

  environment.systemPackages = with pkgs; [
    intel-gpu-tools
    lm_sensors
    usbutils
  ];

  networking = {
    hostName = "sachiel";
    firewall.enable = true;
  };

  services = {
    blueman.enable = true;
    fwupd.enable = true;
  };

  time.timeZone = "Europe/Vienna";

  system.stateVersion = "25.05";
}
