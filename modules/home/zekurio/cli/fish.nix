{
  flake.modules.homeManager.zekurio = {
    config,
    lib,
    pkgs,
    ...
  }: let
    isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
  in {
    programs = {
      atuin = {
        enable = true;
        enableFishIntegration = true;
      };

      fish = {
        enable = true;
        interactiveShellInit = ''
          set fish_greeting

          function __apply_terminal_theme
            set -l flavor
            set -l bat_theme
            set -l starship_config

            if test "$TERMINAL_THEME" = light
              set flavor latte
              set bat_theme "Catppuccin Latte"
              set starship_config "$HOME/.config/starship-latte.toml"
            else
              # Use the dark theme when SSH does not pass a theme hint.
              set flavor frappe
              set bat_theme "Catppuccin Frappe"
              set starship_config "$HOME/.config/starship.toml"
            end

            if test "$STARSHIP_CONFIG" != "$starship_config"
              fish_config theme choose "catppuccin-$flavor"
            end

            set -gx BAT_THEME "$bat_theme"
            set -gx EZA_CONFIG_DIR "$HOME/.config/eza/$flavor"
            set -gx STARSHIP_CONFIG "$starship_config"
          end

          ${lib.optionalString isDarwin ''
            function __sync_macos_theme --on-event fish_prompt
              if defaults read -g AppleInterfaceStyle >/dev/null 2>&1
                set -gx TERMINAL_THEME dark
              else
                set -gx TERMINAL_THEME light
              end

              __apply_terminal_theme
            end

            __sync_macos_theme
          ''}

          ${lib.optionalString (!isDarwin) ''
            __apply_terminal_theme
          ''}
        '';
        shellAliases = {
          ls = "eza";
          ll = "eza -lah";
          la = "eza -la";
          lt = "eza --tree";
          cat = "bat";
        };
      };

      carapace = {
        enable = true;
        enableFishIntegration = true;
      };

      zoxide = {
        enable = true;
        enableFishIntegration = true;
        options = [
          "--cmd"
          "cd"
        ];
      };
    };

    # Fish uses the hint that the SSH client passes. Keep both themes present.
    catppuccin.fish.enable = false;

    xdg.configFile = {
      "fish/themes/catppuccin-latte.theme".source = "${config.catppuccin.sources.fish}/static/catppuccin-latte.theme";
      "fish/themes/catppuccin-frappe.theme".source = "${config.catppuccin.sources.fish}/static/catppuccin-frappe.theme";
    };
  };
}
