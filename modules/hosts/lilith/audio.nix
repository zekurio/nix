{config, ...}: {
  services = {
    pipewire = {
      enable = true;
      alsa = {
        enable = true;
        support32Bit = true;
      };
      pulse.enable = true;
    };
    pulseaudio.enable = false;
  };

  # jack.enable is deprecated because it puts PipeWire's JACK libraries on
  # LD_LIBRARY_PATH for every process. Run a JACK client as `pw-jack <app>`.
  environment.systemPackages = [config.services.pipewire.package.jack];

  security.rtkit.enable = true;
}
