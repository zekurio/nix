{
  programs = {
    atuin = {
      enable = true;
      enableFishIntegration = true;
    };

    fish = {
      enable = true;
      interactiveShellInit = ''
        set fish_greeting

        # Catppuccin Frappé
        set -l text c6d0f5
        set -l overlay0 737994
        set -l surface0 414559
        set -l red e78284
        set -l peach ef9f76
        set -l yellow e5c890
        set -l green a6d189
        set -l teal 81c8be
        set -l sky 99d1db
        set -l blue 8caaee
        set -l pink f4b8e4
        set -l mauve ca9ee6
        set -l flamingo eebebe

        set -g fish_color_normal $text
        set -g fish_color_command $blue
        set -g fish_color_param $flamingo
        set -g fish_color_keyword $red
        set -g fish_color_quote $green
        set -g fish_color_redirection $pink
        set -g fish_color_end $peach
        set -g fish_color_comment $overlay0
        set -g fish_color_error $red
        set -g fish_color_gray $overlay0
        set -g fish_color_selection --background=$surface0
        set -g fish_color_search_match --background=$surface0
        set -g fish_color_option $teal
        set -g fish_color_operator $pink
        set -g fish_color_escape $sky
        set -g fish_color_autosuggestion $overlay0
        set -g fish_color_cancel $red
        set -g fish_color_cwd $yellow
        set -g fish_color_user $teal
        set -g fish_color_host $blue
        set -g fish_color_host_remote $mauve
        set -g fish_color_status $red
        set -g fish_pager_color_progress $overlay0
        set -g fish_pager_color_prefix $pink
        set -g fish_pager_color_completion $text
        set -g fish_pager_color_description $overlay0

        if set -q GHOSTTY_RESOURCES_DIR; and not set -q ZELLIJ
          exec zellij attach --create
        end
      '';
      shellAliases = {
        ls = "eza";
        ll = "eza -lah";
        la = "eza -la";
        lt = "eza --tree";
        codex = "command codex --dangerously-bypass-approvals-and-sandbox";
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
}
