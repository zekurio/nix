{
  flake.modules.nixos.lilith = {pkgs, ...}: {
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
      # offers no other way to name the GPU; hardware.nix keeps amdgpu on card0.
      gpu = {
        apply_gpu_optimisations = "accept-responsibility";
        gpu_device = 0;
        amd_performance_level = "high";
      };
    };
  };
}
