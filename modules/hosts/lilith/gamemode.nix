{
  flake.modules.nixos.lilith = {pkgs, ...}: {
    # COSMIC enables system76-power unless power-profiles-daemon is on.
    services.power-profiles-daemon.enable = true;

    programs.gamemode.settings = {
      general.renice = 10;

      # power-profiles-daemon owns the CPU EPP on amd-pstate. Balanced keeps
      # idle power low on the desktop; performance only for the game's
      # lifetime. The scripts run as the session user, which polkit allows.
      custom = {
        start = "${pkgs.power-profiles-daemon}/bin/powerprofilesctl set performance";
        end = "${pkgs.power-profiles-daemon}/bin/powerprofilesctl set balanced";
      };

      # Hold the RX 6800 at its high DPM level while a game runs instead of
      # letting it ramp on demand. gpu_device is a DRM card index and gamemode
      # offers no other way to name the GPU. The built-in simpledrm always takes
      # card0 from the EFI framebuffer before amdgpu loads from the initrd, and
      # amdgpu reserves its index before evicting it, so the RX 6800 is card1.
      # initcall_blacklist cannot stop simpledrm: the CachyOS kernel's ThinLTO
      # renames the initcall to a stub whose name changes between builds.
      gpu = {
        apply_gpu_optimisations = "accept-responsibility";
        gpu_device = 1;
        amd_performance_level = "high";
      };
    };
  };
}
