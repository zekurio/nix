{
  config,
  pkgs,
  ...
}: {
  # B550M AORUS ELITE: expose the ITE Super I/O fan controller for lm_sensors
  # and CoolerControl. ArchWiki recommends it87 with force_id=0x8628 for B550.
  boot = {
    kernelParams = ["acpi_enforce_resources=lax"];
    kernelModules = ["it87"];
    extraModulePackages = [config.boot.kernelPackages.it87];
    extraModprobeConfig = ''
      options it87 force_id=0x8628
    '';
  };

  environment.systemPackages = with pkgs; [
    lm_sensors
    coolercontrol.coolercontrol-gui
    coolercontrol.coolercontrold
  ];

  systemd.packages = [pkgs.coolercontrol.coolercontrold];
  systemd.services.coolercontrold = {
    wantedBy = ["multi-user.target"];
    environment = {
      CC_HOST_IP4 = "127.0.0.1";
      CC_HOST_IP6 = "::1";
      CC_LOG = "INFO";
    };
  };

  # CoolerControl stores editable profiles/settings here at runtime.
  systemd.tmpfiles.rules = [
    "d /etc/coolercontrol 0755 root root -"
  ];
}
