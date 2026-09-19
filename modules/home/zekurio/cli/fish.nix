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

          ${lib.optionalString isDarwin ''
            function __sync_macos_theme --on-event fish_prompt
              set -l theme
              set -l starship_config

              if defaults read -g AppleInterfaceStyle >/dev/null 2>&1
                set theme catppuccin-frappe
                set starship_config "$HOME/.config/starship.toml"
              else
                set theme catppuccin-latte
                set starship_config "$HOME/.config/starship-latte.toml"
              end

              if test "$STARSHIP_CONFIG" != "$starship_config"
                fish_config theme choose "$theme"
                set -gx STARSHIP_CONFIG "$starship_config"
              end
            end

            __sync_macos_theme
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

    # macOS needs both themes because Fish cannot read Ghostty's active theme.
    catppuccin.fish.enable = !isDarwin;

    xdg.configFile = lib.mkIf isDarwin {
      "fish/themes/catppuccin-latte.theme".source = "${config.catppuccin.sources.fish}/static/catppuccin-latte.theme";
      "fish/themes/catppuccin-frappe.theme".source = "${config.catppuccin.sources.fish}/static/catppuccin-frappe.theme";
    };
  };
}
