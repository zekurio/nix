{ ... }:
{
  programs = {
    atuin = {
      enable = true;
      enableFishIntegration = true;
    };

    direnv = {
      enable = true;
      enableFishIntegration = true;
      nix-direnv.enable = true;
    };

    fish = {
      enable = true;
      interactiveShellInit = ''
        set fish_greeting
      '';
      shellAliases = {
        ls = "eza";
        ll = "eza -lah";
        la = "eza -la";
        lt = "eza --tree";
      };
    };

    carapace = {
      enable = true;
      enableFishIntegration = true;
    };

    starship = {
      enable = true;
      enableFishIntegration = true;
      settings = {
        add_newline = false;
        format = "$directory$character";
        right_format = "$status$git_branch$git_status$java$nodejs$bun$deno$golang$rust$python$nix_shell$username$hostname";

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
          format = "[py $version(\\($virtualenv\\))]($style) ";
          style = "yellow";
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

        username = {
          show_always = false;
          format = "[$user@]($style)";
          style_user = "blue";
          style_root = "bold red";
        };

        hostname = {
          ssh_only = true;
          format = "[$hostname]($style) ";
          style = "blue";
        };

        java = {
          format = "[java $version]($style) ";
          style = "red";
        };

        nodejs = {
          format = "[node $version]($style) ";
          style = "green";
        };

        bun = {
          format = "[bun $version]($style) ";
          style = "yellow";
        };

        deno = {
          format = "[deno $version]($style) ";
          style = "white";
        };

        golang = {
          format = "[go $version]($style) ";
          style = "cyan";
        };

        rust = {
          format = "[rs $version]($style) ";
          style = "red";
        };
      };
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
}
