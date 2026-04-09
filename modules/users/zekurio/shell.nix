{...}: {
  programs = {
    atuin = {
      enable = true;
      enableNushellIntegration = true;
    };

    direnv = {
      enable = true;
      enableNushellIntegration = true;
      nix-direnv.enable = true;
    };

    nushell = {
      enable = true;
      shellAliases = {
        ls = "eza";
        ll = "eza -lah";
        la = "eza -la";
        lt = "eza --tree";
      };
    };

    carapace = {
      enable = true;
      enableNushellIntegration = true;
    };

    starship = {
      enable = true;
      enableNushellIntegration = true;
      settings = {
        add_newline = false;
        format = "$python$directory$character";
        right_format = "$status$git_branch$git_status";

        character = {
          success_symbol = "[❯](red)[❯](yellow)[❯](green)";
          error_symbol = "[❯](red)[❯](yellow)[❯](green)";
          vicmd_symbol = "[❮](green)[❮](yellow)[❮](red)";
        };

        git_branch = {
          format = "[$branch]($style) ";
          style = "bold green";
        };

        python = {
          format = "[(\\($virtualenv\\) )]($style)";
          style = "white";
        };

        git_status = {
          format = "$all_status$ahead_behind ";
          ahead = "[⬆](bold purple) ";
          behind = "[⬇](bold purple) ";
          staged = "[✚](green) ";
          deleted = "[✖](red) ";
          renamed = "[➜](purple) ";
          stashed = "[✭](cyan) ";
          untracked = "[◼](white) ";
          modified = "[✱](blue) ";
          conflicted = "[═](yellow) ";
          diverged = "⇕ ";
          up_to_date = "";
        };

        directory = {
          style = "blue";
          truncation_length = 1;
          truncation_symbol = "";
          fish_style_pwd_dir_length = 1;
        };

        cmd_duration = {
          format = "[$duration]($style) ";
        };

        line_break.disabled = true;

        status = {
          disabled = false;
          symbol = "✘ ";
        };
      };
    };

    zoxide = {
      enable = true;
      enableNushellIntegration = true;
      options = ["--cmd" "cd"];
    };
  };
}
