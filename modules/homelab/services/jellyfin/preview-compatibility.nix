{
  flake.modules.nixos.homelab = {
    config,
    lib,
    ...
  }: let
    dataDir = config.services.jellyfin.dataDir;
    configDir = config.services.jellyfin.configDir;
    publicUrl = config.services.homelab.jellyfin.publicUrl;
    disabledPluginDir = "/var/backup/jellyfin/plugins-disabled-for-12-rc7";
  in {
    config = lib.mkIf config.services.homelab.jellyfin.enable {
      # Run after the cold backup. RC7 otherwise rejects 10.11's null encoder
      # preset and bare published URL, while upstream recommends leaving
      # external plugins unloaded during preview testing.
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

        disabled_plugin_dir=${lib.escapeShellArg disabledPluginDir}
        mkdir --parents --mode=0700 "$disabled_plugin_dir"
        for plugin in Trakt_30.0.0.0 TheTVDB_22.0.0.0; do
          plugin_path=${lib.escapeShellArg "${dataDir}/plugins"}/"$plugin"
          if [[ -e "$plugin_path" ]]; then
            mv --no-target-directory "$plugin_path" "$disabled_plugin_dir/$plugin"
          fi
        done
      '';
    };
  };
}
