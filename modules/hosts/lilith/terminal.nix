{...}: {
  flake.modules.nixos.lilith = {pkgs, ...}: let
    ghosttyLauncher = pkgs.writeShellApplication {
      name = "ghostty-launcher";
      runtimeInputs = [
        pkgs.jq
        pkgs.niri
      ];
      text = ''
        windows="$(niri msg --json windows 2>/dev/null || true)"
        window_id="$(
          jq -r 'first(.[] | select(.app_id == "com.mitchellh.ghostty" or .app_id == "ghostty")) | .id // empty' \
            <<< "$windows"
        )"

        if [[ -n "$window_id" ]] && niri msg action focus-window --id "$window_id"; then
          exit 0
        fi

        exec ${pkgs.ghostty}/bin/ghostty "$@"
      '';
    };
    ghostty = pkgs.symlinkJoin {
      name = "ghostty-single-window";
      paths = [pkgs.ghostty];
      nativeBuildInputs = [pkgs.makeWrapper];
      postBuild = ''
        rm "$out/bin/ghostty"
        makeWrapper ${ghosttyLauncher}/bin/ghostty-launcher "$out/bin/ghostty"

        desktop="$out/share/applications/com.mitchellh.ghostty.desktop"
        cp --remove-destination "$(readlink -f "$desktop")" "$desktop"
        substituteInPlace "$desktop" \
          --replace-fail "DBusActivatable=true" "DBusActivatable=false"
      '';
    };
  in {
    environment.systemPackages = [ghostty];

    home-manager.users.zekurio.programs.ghostty.settings = {
      command = "${pkgs.zellij}/bin/zellij attach --create ghostty";
      keybind = ["ctrl+shift+n=unbind"];
    };
  };
}
