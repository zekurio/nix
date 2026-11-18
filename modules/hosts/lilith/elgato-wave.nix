{pkgs, ...}: let
  # jmansar's workaround for the Wave's microphone going silent when
  # playback starts before capture. Headphones on the mic's jack trigger it.
  wavexlr-on-linux-cfg = pkgs.fetchFromGitHub {
    owner = "jmansar";
    repo = "wavexlr-on-linux-cfg";
    rev = "b9385e12358726fa530570881cee7c5d4d493413";
    hash = "sha256-Z5uCgTGh62QIRBQ5Aj2IpsxZgjKyTY5Zbgq0M5WoW48=";
  };
  waveDeviceFix = pkgs.runCommand "wireplumber-wavedevicefix" {} ''
    install -Dm644 ${wavexlr-on-linux-cfg}/files/cfg1/wavedevicefix.lua \
      $out/share/wireplumber/scripts/wavedevicefix.lua
  '';
in {
  # The script links the mic to a null sink so capture is always running,
  # then creates the playback sink itself, named "Wave3 Sink", once capture
  # has run for 1.5 s. WirePlumber's own playback node for the device is
  # disabled, and the source is renamed to the name the script waits for.
  # Upstream's files/cfg1/51-wave3.conf, translated.
  services.pipewire.wireplumber = {
    configPackages = [waveDeviceFix];
    extraConfig."51-elgato-wave3" = {
      "wireplumber.components" = [
        {
          name = "wavedevicefix.lua";
          type = "script/lua";
          provides = "custom.wave3fix";
          arguments.device = "wave3";
        }
      ];
      "wireplumber.profiles".main."custom.wave3fix" = "required";
      "monitor.alsa.rules" = [
        {
          matches = [{"node.name" = "~alsa_output.usb-Elgato_Systems_Elgato_Wave_3_*";}];
          actions.update-props."node.disabled" = true;
        }
        {
          matches = [{"node.name" = "~alsa_input.usb-Elgato_Systems_Elgato_Wave_3_*";}];
          actions.update-props."node.name" = "wave3-source";
        }
      ];
    };
  };
}
