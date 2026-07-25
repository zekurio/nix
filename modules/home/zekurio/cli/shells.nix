{
  flake.modules.homeManager.zekurio = {
    config,
    lib,
    pkgs,
    ...
  }: let
    isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
    pathEntries =
      [
        "${config.home.homeDirectory}/.local/bin"
      ]
      ++ lib.optionals isDarwin [
        "/opt/homebrew/bin"
        "/opt/homebrew/sbin"
      ]
      ++ lib.optionals (!isDarwin) [
        # NixOS installs privileged commands such as sudo as setuid wrappers.
        "/run/wrappers/bin"
      ]
      ++ [
        "${config.home.profileDirectory}/bin"
        "/run/current-system/sw/bin"
        "/nix/var/nix/profiles/default/bin"
        "/usr/local/bin"
        "/usr/bin"
        "/bin"
        "/usr/sbin"
        "/sbin"
      ];
  in {
    programs = {
      atuin = {
        enable = true;
        enableFishIntegration = true;
        enableNushellIntegration = true;
      };

      fish = {
        enable = true;
        interactiveShellInit = ''
          set fish_greeting

        '';
      };

      nushell = {
        enable = true;
        environmentVariables =
          config.home.sessionVariables
          // lib.optionalAttrs isDarwin {
            HOMEBREW_CELLAR = "/opt/homebrew/Cellar";
            HOMEBREW_PREFIX = "/opt/homebrew";
            HOMEBREW_REPOSITORY = "/opt/homebrew/Library/.homebrew-is-managed-by-nix";
          }
          // {
            PATH = lib.hm.nushell.mkNushellInline ''
              (${lib.hm.nushell.toNushell {} pathEntries} | append $env.PATH | uniq)
            '';
          };
        settings = {
          show_banner = false;
          table.mode = "rounded";
        };
        extraConfig = lib.mkOrder 100 ''
          # Preserve Nushell's structured built-ins before applying the shared
          # Fish-style aliases below.
          alias nu-ls = ls
          alias nu-cat = cat
          alias nu-open = open
        '';
        shellAliases = lib.optionalAttrs isDarwin {
          # On macOS, keep `open` compatible with other applications.
          open = "^open";
        };
      };

      carapace = {
        enable = true;
        enableFishIntegration = true;
        enableNushellIntegration = true;
      };

      zoxide = {
        enable = true;
        enableFishIntegration = true;
        enableNushellIntegration = true;
        options = [
          "--cmd"
          "cd"
        ];
      };
    };

    # Shell colors come from the fixed global Catppuccin flavor.
    catppuccin.fish.enable = true;
    catppuccin.nushell.enable = true;
  };
}
