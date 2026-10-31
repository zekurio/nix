{lib, ...}: {
  home-manager.users.zekurio.programs.ghostty = {
    enable = true;
    # The shared profile's opacity barely shows the blur KWin draws behind
    # Ghostty. Ghostty's settings type keeps duplicate keys, so a plain
    # definition would write the option twice instead of replacing it.
    settings.background-opacity = lib.mkForce 0.85;
    # Treat Alt as the Linux equivalent of macOS Command for the shortcuts
    # used most often. Alt+arrows remain available to shells, and Ghostty
    # already binds Alt+1-9 to tabs on Linux.
    settings.keybind = [
      "alt+c=copy_to_clipboard"
      "alt+v=paste_from_clipboard"
      "alt+t=new_tab"
      "alt+w=close_surface"
      "alt+shift+w=close_tab"
      "alt+d=new_split:right"
      "alt+shift+d=new_split:down"
      "alt+bracket_left=goto_split:previous"
      "alt+bracket_right=goto_split:next"
      "alt+shift+bracket_left=previous_tab"
      "alt+shift+bracket_right=next_tab"
      "alt+enter=toggle_fullscreen"
      "alt+shift+enter=toggle_split_zoom"
      "alt+equal=increase_font_size:1"
      "alt+plus=increase_font_size:1"
      "alt+minus=decrease_font_size:1"
      "alt+digit_0=reset_font_size"

      "ctrl+alt+arrow_up=goto_split:up"
      "ctrl+alt+arrow_down=goto_split:down"
      "ctrl+alt+arrow_left=goto_split:left"
      "ctrl+alt+arrow_right=goto_split:right"
      "ctrl+alt+shift+arrow_up=resize_split:up,30"
      "ctrl+alt+shift+arrow_down=resize_split:down,30"
      "ctrl+alt+shift+arrow_left=resize_split:left,30"
      "ctrl+alt+shift+arrow_right=resize_split:right,30"
    ];
  };
}
