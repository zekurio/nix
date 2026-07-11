{
  config,
  inputs,
  pkgs,
  ...
}: let
  wave3WirePlumberConfig = pkgs.runCommand "wave3-wireplumber-config" {} ''
    install -Dm0644 ${inputs.wavexlr-on-linux-cfg}/files/cfg1/51-wave3.conf \
      $out/share/wireplumber/wireplumber.conf.d/51-wave3.conf
    install -Dm0644 ${inputs.wavexlr-on-linux-cfg}/files/cfg1/wavedevicefix.lua \
      $out/share/wireplumber/scripts/wavedevicefix.lua
  '';
in {
  boot = {
    extraModulePackages = [
      config.boot.kernelPackages.it87
    ];
    kernelModules = [
      "it87"
    ];
    extraModprobeConfig = ''
      options it87 force_id=0x8628
    '';
    kernelParams = [
      "acpi_enforce_resources=lax"
    ];
  };

  environment.systemPackages = [
    pkgs.lm_sensors
  ];

  programs.coolercontrol.enable = true;

  services.pipewire.wireplumber.configPackages = [
    wave3WirePlumberConfig
  ];
}
