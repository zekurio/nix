{
  inputs,
  lib,
  pkgs,
  ...
}: let
  agents = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
  piTheme = "catppuccin-latte-blue/catppuccin-frappe-blue";
  configurePiTheme = pkgs.writeShellScript "configure-pi-theme" ''
    set -euo pipefail

    settings="$HOME/.pi/agent/settings.json"
    mkdir -p "$(dirname "$settings")"
    temporary="$(mktemp "$(dirname "$settings")/.settings.json.XXXXXX")"
    trap 'rm -f "$temporary"' EXIT

    if [[ -f "$settings" ]]; then
      ${pkgs.jq}/bin/jq --arg theme '${piTheme}' '.theme = $theme' "$settings" > "$temporary"
      ${pkgs.coreutils}/bin/chmod --reference="$settings" "$temporary"
    else
      ${pkgs.jq}/bin/jq -n --arg theme '${piTheme}' '{theme: $theme}' > "$temporary"
    fi

    mv "$temporary" "$settings"
    trap - EXIT
  '';
in {
  home = {
    packages = with agents; [
      claude-code
      codex
    ];

    file = {
      ".pi/agent/themes/catppuccin-latte-blue.json" = {
        source = ./themes/catppuccin-latte-blue.json;
        force = true;
      };
      ".pi/agent/themes/catppuccin-frappe-blue.json" = {
        source = ./themes/catppuccin-frappe-blue.json;
        force = true;
      };
    };

    activation.configurePiTheme = lib.hm.dag.entryAfter ["writeBoundary"] ''
      $DRY_RUN_CMD ${configurePiTheme}
    '';
  };
}
