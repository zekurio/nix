{
  programs.starship = {
    enable = true;
    enableNushellIntegration = true;
    settings = {
      add_newline = false;
      format = "$directory$character";
      right_format = "$status$git_branch$git_status$java$nodejs$bun$deno$golang$rust$python$nix_shell$username$hostname";

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
        style = "white";
      };

      git_branch = {
        format = "[$branch]($style) ";
        style = "purple";
      };
      git_status = {
        format = "[$all_status$ahead_behind]($style) ";
        style = "red";
      };

      golang = {
        format = "[go $version]($style) ";
        style = "cyan";
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
