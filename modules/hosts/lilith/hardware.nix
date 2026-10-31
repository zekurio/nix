{
  config,
  inputs,
  pkgs,
  ...
}: let
  system = pkgs.stdenv.hostPlatform.system;
in {
  nixpkgs.hostPlatform = "x86_64-linux";

  # The cached CachyOS preset keeps its upstream kernel configuration. Do not
  # add a nixpkgs follow to the Chaotic input or this becomes a local build.
  boot = {
    kernelPackages = inputs.chaotic.legacyPackages.${system}.linuxPackages_cachyos;
    kernelModules = [
      "kvm-amd"
      "it87"
      # Proton only uses NT synchronisation primitives when /dev/ntsync
      # exists at launch; nothing autoloads the module.
      "ntsync"
    ];
    extraModulePackages = [
      config.boot.kernelPackages.it87
    ];
    # This board's ITE IT8628 sensor is hidden behind ACPI resource claims;
    # the out-of-tree driver and relaxed check were required on old Lilith.
    extraModprobeConfig = ''
      options it87 force_id=0x8628
    '';
    kernelParams = [
      "acpi_enforce_resources=lax"
      # Update GPU page tables from the CPU for both graphics and compute
      # instead of queueing them on the GPU. Fixes camera-pan frame pacing
      # in Control Resonant under RADV; keep it.
      "amdgpu.vm_update_mode=3"
      # Single-user gaming desktop: retpolines, Safe RET and the other
      # speculative-execution mitigations only cost CPU-bound frame time.
      "mitigations=off"
    ];
  };

  hardware = {
    cpu.amd.updateMicrocode = true;
    amdgpu.initrd.enable = true;
    graphics = {
      enable = true;
      enable32Bit = true;
    };
    bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
  };

  # RADV and radeonsi from Mesa are the supported defaults for the RX 6800;
  # AMDVLK, global RADV flags and overdrive masks are intentionally absent.
  services.fstrim.enable = true;
  services.fwupd.enable = true;
  # Both drives are NVMe; the kernel still picks mq-deadline, which only
  # adds queueing overhead on hardware with its own command queues.
  services.udev.extraRules = ''
    ACTION=="add|change", KERNEL=="nvme[0-9]*n[0-9]*", ATTR{queue/scheduler}="none"
  '';
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
}
