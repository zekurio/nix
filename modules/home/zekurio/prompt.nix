{
  programs.starship = {
    enable = true;
    enableFishIntegration = true;
    settings = {
      add_newline = false;
      format = "$directory$character";
      right_format = "$status$git_branch$git_status$username$hostname";

      character = {
        success_symbol = "[❯](red)[❯](yellow)[❯](green)";
        error_symbol = "[❯](red)[❯](yellow)[❯](green)";
        vicmd_symbol = "[❮](green)[❮](yellow)[❮](red)";
      };

      git_branch = {
        format = "[$branch]($style) ";
        style = "purple";
      };
      git_status = {
        format = "[$all_status$ahead_behind]($style) ";
        style = "red";
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
    };
  };
}
