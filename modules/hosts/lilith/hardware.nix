{inputs, ...}: {
  flake.modules.nixos.lilith = {
    config,
    pkgs,
    ...
  }: let
    system = pkgs.stdenv.hostPlatform.system;
  in {
    # The cached CachyOS preset keeps its upstream kernel configuration. Do not
    # add a nixpkgs follow to the Chaotic input or this becomes a local build.
    boot = {
      kernelPackages = inputs.chaotic.legacyPackages.${system}.linuxPackages_cachyos;
      kernelModules = [
        "kvm-amd"
        "it87"
      ];
      extraModulePackages = [
        config.boot.kernelPackages.it87
      ];
      # This board's ITE IT8628 sensor is hidden behind ACPI resource claims;
      # the out-of-tree driver and relaxed check were required on old Lilith.
      extraModprobeConfig = ''
        options it87 force_id=0x8628
      '';
      kernelParams = ["acpi_enforce_resources=lax"];
    };

    hardware = {
      cpu.amd.updateMicrocode = true;
      amdgpu.initrd.enable = true;
      graphics = {
        enable = true;
        enable32Bit = true;
      };
    };

    # RADV and radeonsi from Mesa are the supported defaults for the RX 6800;
    # AMDVLK, global RADV flags and overdrive masks are intentionally absent.
    services.fstrim.enable = true;
    programs.coolercontrol.enable = true;

    environment.systemPackages = with pkgs; [
      clinfo
      libva-utils
      lm_sensors
      mesa-demos
      pciutils
      radeontop
      sbctl
      usbutils
      vulkan-tools
    ];
  };
}
