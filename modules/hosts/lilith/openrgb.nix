{
  flake.modules.nixos.lilith = {pkgs, ...}: {
    environment.systemPackages = [
      pkgs.openrgb
    ];
    services.udev.packages = [pkgs.openrgb];
    hardware.i2c.enable = true;
    boot = {
      kernelModules = ["i2c-piix4"];
      # i2c-piix4 autoloads the SPD EEPROM driver, whose page selects collide
      # with OpenRGB writing to the ENE DRAM controllers on the same SMBus.
      # Nothing here reads SPD data, so keep it out.
      blacklistedKernelModules = ["ee1004"];
    };

    home-manager.users.zekurio.xdg.configFile = {
      # Hardware Static mode keeps the color after OpenRGB exits.
      "autostart/OpenRGB.desktop" = {
        force = true;
        text = ''
          [Desktop Entry]
          Type=Application
          Name=OpenRGB
          Exec=${pkgs.openrgb}/bin/openrgb --mode Static --color FF050A
          Terminal=false
          StartupNotify=false
        '';
      };

      # Plasma also created a separate GUI autostart entry for this app.
      "autostart/org.openrgb.OpenRGB.desktop" = {
        force = true;
        text = ''
          [Desktop Entry]
          Type=Application
          Name=OpenRGB
          Exec=${pkgs.openrgb}/bin/openrgb
          Hidden=true
        '';
      };
    };
  };
}
