{
  lib,
  config,
  ...
}: let
  cfg = config.modules.shell;
in {
  config = lib.mkIf cfg.enable {
    home-manager.users.zekurio.programs.starship = {
      enable = true;
      enableFishIntegration = true;
      settings = {
        add_newline = false;
        format = "$directory$character";
        right_format = "$status$jj$java$nodejs$bun$deno$golang$rust$python$nix_shell$username$hostname";

        character = {
          success_symbol = "[❯](red)[❯](yellow)[❯](green)";
          error_symbol = "[❯](red)[❯](yellow)[❯](green)";
          vicmd_symbol = "[❮](green)[❮](yellow)[❮](red)";
        };

        jj = {
          format = "[$symbol$change_id(:$bookmarks)]($style)[$conflict](bold red)[$divergent](bold yellow)[$immutable](bold cyan) ";
          style = "bold green";
          symbol = " ";
        };

        git_branch.disabled = true;

        python = {
          format = "[py $version(\\($virtualenv\\))]($style) ";
          style = "yellow";
        };

        git_status.disabled = true;

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

        nix_shell = {
          format = "[nix $state]($style) ";
          style = "blue";
        };
      };
    };
  };
}
