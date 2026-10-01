{
  flake.modules.nixos.lilith = {
    home-manager.users.zekurio.programs.kitty = {
      enable = true;
      settings = {
        font_family = "FiraCode Nerd Font";
        font_size = 11.5;
        remember_window_size = false;
        initial_window_width = "150c";
        initial_window_height = "38c";
        window_padding_width = 8;
        background_opacity = 0.96;
        enabled_layouts = "splits:equalize_on_close=true";
      };
      keybindings = {
        # Treat Alt as the Linux equivalent of macOS Command for the
        # shortcuts used most often. Alt+arrows remain available to shells.
        "alt+c" = "copy_to_clipboard";
        "alt+v" = "paste_from_clipboard";
        "alt+t" = "new_tab";
        "alt+w" = "close_window";
        "alt+shift+w" = "close_tab";
        "alt+d" = "launch --location=vsplit --cwd=current";
        "alt+shift+d" = "launch --location=hsplit --cwd=current";
        "alt+[" = "previous_window";
        "alt+]" = "next_window";
        "alt+shift+[" = "previous_tab";
        "alt+shift+]" = "next_tab";
        "alt+enter" = "toggle_fullscreen";
        "alt+shift+enter" = "toggle_layout stack";
        "alt+1" = "goto_tab 1";
        "alt+2" = "goto_tab 2";
        "alt+3" = "goto_tab 3";
        "alt+4" = "goto_tab 4";
        "alt+5" = "goto_tab 5";
        "alt+6" = "goto_tab 6";
        "alt+7" = "goto_tab 7";
        "alt+8" = "goto_tab 8";
        "alt+9" = "goto_tab -1";
        "alt+equal" = "change_font_size all +1.0";
        "alt+plus" = "change_font_size all +1.0";
        "alt+minus" = "change_font_size all -1.0";
        "alt+0" = "change_font_size all 0";

        "ctrl+alt+up" = "neighboring_window up";
        "ctrl+alt+down" = "neighboring_window down";
        "ctrl+alt+left" = "neighboring_window left";
        "ctrl+alt+right" = "neighboring_window right";
        "ctrl+alt+shift+up" = "resize_window taller 3";
        "ctrl+alt+shift+down" = "resize_window shorter 3";
        "ctrl+alt+shift+left" = "resize_window narrower 3";
        "ctrl+alt+shift+right" = "resize_window wider 3";
      };
    };
  };
}
