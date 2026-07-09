{
  # Starship palette (Frappé) provided by catppuccin/nix; the module sets
  # `palette` and injects the color definitions used by the styles below.
  catppuccin.starship.enable = true;

  programs.starship = {
    enable = true;
    enableFishIntegration = true;
    settings = {
      add_newline = false;
      format = "$directory$character";
      right_format = "$status$cmd_duration$git_branch$git_status$java$nodejs$bun$deno$golang$rust$python$nix_shell$time$username$hostname";

      bun = {
        format = "[bun $version]($style) ";
        style = "yellow";
      };

      character = {
        success_symbol = "[❯](red)[❯](yellow)[❯](green)";
        error_symbol = "[❯](red)[❯](yellow)[❯](green)";
        vicmd_symbol = "[❮](green)[❮](yellow)[❮](red)";
      };

      deno = {
        format = "[deno $version]($style) ";
        style = "";
      };

      git_branch = {
        format = "[$branch]($style) ";
        style = "blue";
      };
      git_status = {
        format = "[$all_status$ahead_behind]($style) ";
        style = "red";
      };

      golang = {
        format = "[go $version]($style) ";
        style = "teal";
      };

      directory = {
        style = "blue";
        truncation_length = 1;
        truncation_symbol = "";
        fish_style_pwd_dir_length = 1;
      };

      java = {
        format = "[java $version]($style) ";
        style = "red";
      };

      cmd_duration = {
        format = "[$duration]($style) ";
        min_time = 1000;
        style = "yellow";
      };

      line_break.disabled = true;

      nix_shell = {
        format = "[nix $state]($style) ";
        style = "blue";
      };

      nodejs = {
        format = "[node $version]($style) ";
        style = "green";
      };

      python = {
        format = "[py $version(\\($virtualenv\\))]($style) ";
        style = "yellow";
      };

      rust = {
        format = "[rs $version]($style) ";
        style = "red";
      };

      status = {
        disabled = false;
        format = "[$symbol$status]($style) ";
        symbol = "✘ ";
        style = "red";
      };

      time = {
        disabled = false;
        format = "[$time]($style) ";
        style = "teal";
        time_format = "%H:%M";
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
    };
  };
}
