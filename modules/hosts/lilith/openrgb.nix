{
  flake.modules.nixos.lilith = {pkgs, ...}: {
    environment.systemPackages = [
      (pkgs.openrgb.withPlugins [pkgs.openrgb-plugin-effects])
    ];
    services.udev.packages = [pkgs.openrgb];
    hardware.i2c.enable = true;
    boot.kernelModules = ["i2c-piix4"];
  };
}
