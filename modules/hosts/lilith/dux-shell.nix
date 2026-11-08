{
  config,
  pkgs,
  ...
}: let
  inherit (config.programs) dux-shell niri;

  # What `dms setup` deploys, taken from the installed version's source.
  embedded = "${dux-shell.package.src}/core/internal/config/embedded";

  # The stock fragments under ~/.config/niri/dms, which DMS owns.
  fragments = pkgs.runCommand "dux-niri-fragments" {} ''
    mkdir $out
    for name in alttab colors input layout; do
      cp ${embedded}/niri-$name.kdl $out/$name.kdl
    done
    substitute ${embedded}/niri-binds.kdl $out/binds.kdl \
      --replace-fail '{{TERMINAL_COMMAND}}' kitty
  '';

  # DMS's config.kdl, which leaves the starting of DMS to systemd. DMS can
  # write window rules and wallpaper blur without its template including
  # them, and its include repair cannot write to the store, so the missing
  # includes are added here.
  niriConfig =
    pkgs.runCommand "niri-config.kdl" {
      nativeBuildInputs = [niri.package];
    } ''
      cp ${embedded}/niri.kdl $out
      chmod +w $out
      for name in windowrules wpblur; do
        grep -q "\"dms/$name.kdl\"" $out ||
          echo "include optional=true \"dms/$name.kdl\"" >> $out
      done

      # Catch syntax that the niri build no longer accepts.
      mkdir -p check/dms
      cp $out check/config.kdl
      cp ${fragments}/* check/dms/
      niri validate --config check/config.kdl
    '';
in {
  programs = {
    dux-shell.enable = true;
    # File search for the DMS launcher.
    dux-search.enable = true;
    dux-files.enable = true;
  };

  home-manager.users.zekurio = {
    config,
    lib,
    ...
  }: {
    xdg.configFile."niri/config.kdl".source = niriConfig;

    # DMS's settings pages rewrite the fragments, so they are copied once
    # instead of linked. DMS creates missing ones empty, and an empty
    # binds.kdl leaves niri without keybinds, so empty files count as missing.
    home.activation.duxNiriFragments = lib.hm.dag.entryAfter ["writeBoundary"] ''
      dir=${lib.escapeShellArg "${config.xdg.configHome}/niri/dms"}
      run mkdir -p "$dir"
      for file in ${fragments}/*; do
        target="$dir/''${file##*/}"
        if [ ! -s "$target" ]; then
          run install -m 644 "$file" "$target"
        fi
      done
    '';
  };
}
