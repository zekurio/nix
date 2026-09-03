{
  flake.modules.nixos.homelab = {
    config,
    lib,
    ...
  }: let
    configDir = config.services.jellyfin.configDir;
    publicUrl = config.services.homelab.jellyfin.publicUrl;
  in {
    config = lib.mkIf config.services.homelab.jellyfin.enable {
      # Run after the cold backup. RC7 otherwise rejects 10.11's null encoder
      # preset and bare published URL, resetting transcoding settings and
      # dropping the published URL respectively.
      systemd.services.jellyfin.preStart = lib.mkAfter ''
        encoding_xml=${lib.escapeShellArg "${configDir}/encoding.xml"}
        null_preset='<EncoderPreset xsi:nil="true" />'
        if grep --fixed-strings --quiet "$null_preset" "$encoding_xml"; then
          sed --in-place "s|$null_preset|<EncoderPreset>auto</EncoderPreset>|" "$encoding_xml"
        fi

        network_xml=${lib.escapeShellArg "${configDir}/network.xml"}
        bare_published_url=${lib.escapeShellArg "<string>${publicUrl}</string>"}
        scoped_published_url=${lib.escapeShellArg "<string>all=${publicUrl}</string>"}
        if grep --fixed-strings --quiet "$bare_published_url" "$network_xml"; then
          sed --in-place "s|$bare_published_url|$scoped_published_url|" "$network_xml"
        fi
      '';
    };
  };
}
