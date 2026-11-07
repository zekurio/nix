{config, ...}: {
  services = {
    pipewire = {
      enable = true;
      alsa = {
        enable = true;
        support32Bit = true;
      };
      pulse.enable = true;
      wireplumber.extraConfig."90-monitor-audio" = {
        "monitor.alsa.rules" = [
          {
            matches = [
              {"node.name" = "alsa_output.pci-0000_09_00.1.hdmi-stereo-extra2";}
            ];
            actions.update-props = {
              # 96 kHz initially cleared static on the MAG274QRF-QD;
              # recurrence after reboot is still under investigation.
              # HDMI/DP carries 24-bit samples in ALSA's S32LE container.
              "audio.format" = "S32LE";
              "audio.rate" = 96000;
            };
          }
        ];
      };
    };
    pulseaudio.enable = false;
  };

  # jack.enable is deprecated because it puts PipeWire's JACK libraries on
  # LD_LIBRARY_PATH for every process. Run a JACK client as `pw-jack <app>`.
  environment.systemPackages = [config.services.pipewire.package.jack];

  security.rtkit.enable = true;
}
