{
  flake.modules.nixos.lilith = {
    services = {
      pipewire = {
        enable = true;
        alsa = {
          enable = true;
          support32Bit = true;
        };
        pulse.enable = true;
        jack.enable = true;
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

    security.rtkit.enable = true;
  };
}
