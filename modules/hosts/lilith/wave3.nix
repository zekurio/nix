{inputs, ...}: {
  flake.modules.nixos.lilith = {pkgs, ...}: let
    wave3WirePlumberConfig = pkgs.runCommand "wave3-wireplumber-config" {} ''
      install -Dm0644 ${inputs.wavexlr-on-linux-cfg}/files/cfg1/51-wave3.conf \
        $out/share/wireplumber/wireplumber.conf.d/51-wave3.conf
      install -Dm0644 ${inputs.wavexlr-on-linux-cfg}/files/cfg1/wavedevicefix.lua \
        $out/share/wireplumber/scripts/wavedevicefix.lua
    '';
  in {
    # Keep capture active before playback starts. The Wave:3 otherwise stops
    # sending microphone audio when PipeWire uses both device directions.
    services.pipewire.wireplumber.configPackages = [wave3WirePlumberConfig];
  };
}
