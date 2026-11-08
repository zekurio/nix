{
  home-manager.users.zekurio.programs.kitty = {
    enable = true;
    # The shared profile's opacity barely shows the blur niri draws behind
    # the terminal.
    settings.background_opacity = 0.85;
    # Treat Alt as the Linux equivalent of macOS Command for the shortcuts
    # used most often. Alt+arrows remain available to shells.
    keybindings =
      {
        "alt+c" = "copy_to_clipboard";
        "alt+v" = "paste_from_clipboard";
        "alt+t" = "new_tab_with_cwd";
        "alt+w" = "close_window";
        "alt+shift+w" = "close_tab";
        # kitty names a split after its divider: vsplit puts the new window
        # to the right, hsplit below.
        "alt+d" = "launch --location=vsplit --cwd=current";
        "alt+shift+d" = "launch --location=hsplit --cwd=current";
        "alt+[" = "previous_window";
        "alt+]" = "next_window";
        "alt+shift+[" = "previous_tab";
        "alt+shift+]" = "next_tab";
        "alt+enter" = "toggle_fullscreen";
        "alt+shift+enter" = "toggle_layout stack";
        "alt+equal" = "change_font_size current +1";
        "alt+plus" = "change_font_size current +1";
        "alt+minus" = "change_font_size current -1";
        "alt+0" = "change_font_size current 0";

        "ctrl+alt+up" = "neighboring_window up";
        "ctrl+alt+down" = "neighboring_window down";
        "ctrl+alt+left" = "neighboring_window left";
        "ctrl+alt+right" = "neighboring_window right";
        # kitty resizes the focused window, not the divider, so these only
        # move the divider in the arrow's direction for the left or top one.
        "ctrl+alt+shift+up" = "resize_window shorter 3";
        "ctrl+alt+shift+down" = "resize_window taller 3";
        "ctrl+alt+shift+left" = "resize_window narrower 3";
        "ctrl+alt+shift+right" = "resize_window wider 3";
      }
      # Ghostty bound Alt+1-9 to tabs on Linux; kitty does not.
      // builtins.listToAttrs (map (n: {
        name = "alt+${toString n}";
        value = "goto_tab ${toString n}";
      }) [1 2 3 4 5 6 7 8 9]);
  };
}
