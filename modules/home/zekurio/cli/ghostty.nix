{
  flake.modules.homeManager.zekurio = {
    lib,
    pkgs,
    ...
  }: let
    isDarwin = pkgs.stdenv.hostPlatform.isDarwin;

    # Keybinds shared verbatim by lilith (Linux) and sachiel (macOS).
    # Ghostty's built-in defaults differ per OS (Ctrl-based on Linux,
    # Cmd-based on macOS); we standardize on the Ctrl-style set so muscle
    # memory transfers, layered on top of each platform's native extras.
    # Super/Cmd cannot be shared: niri/DMS owns Super on lilith.
    unifiedKeybinds = [
      # Copy & paste
      "ctrl+shift+c=copy_to_clipboard"
      "ctrl+shift+v=paste_from_clipboard"
      # Tabs & windows (ctrl+shift+n=new_window is deliberately absent:
      # lilith unbinds it for its single-window wrapper)
      "ctrl+shift+t=new_tab"
      "ctrl+shift+q=quit"
      "ctrl+shift+w=close_surface"
      "ctrl+shift+arrow_left=previous_tab"
      "ctrl+shift+arrow_right=next_tab"
      "ctrl+page_up=previous_tab"
      "ctrl+page_down=next_tab"
      # Splits
      "ctrl+shift+o=new_split:right"
      "ctrl+shift+e=new_split:down"
      "ctrl+shift+enter=toggle_split_zoom"
      "ctrl+shift+bracket_left=goto_split:previous"
      "ctrl+shift+bracket_right=goto_split:next"
      "ctrl+alt+arrow_up=goto_split:up"
      "ctrl+alt+arrow_down=goto_split:down"
      "ctrl+alt+arrow_left=goto_split:left"
      "ctrl+alt+arrow_right=goto_split:right"
      "ctrl+shift+arrow_up=resize_split:up,10"
      "ctrl+shift+arrow_down=resize_split:down,10"
      "ctrl+shift+arrow_left=resize_split:left,10"
      "ctrl+shift+arrow_right=resize_split:right,10"
      # Scrolling & prompts
      "shift+home=scroll_to_top"
      "shift+end=scroll_to_bottom"
      "shift+page_up=scroll_page_up"
      "shift+page_down=scroll_page_down"
      "ctrl+shift+page_up=jump_to_prompt:-1"
      "ctrl+shift+page_down=jump_to_prompt:1"
      # Search, selection, inspector
      "ctrl+shift+f=start_search"
      "ctrl+shift+a=select_all"
      "ctrl+shift+i=inspector:toggle"
      # Font size, config, command palette, fullscreen, scrollback
      "ctrl+==increase_font_size:1"
      "ctrl++=increase_font_size:1"
      "ctrl+-=decrease_font_size:1"
      "ctrl+0=reset_font_size"
      "ctrl+,=open_config"
      "ctrl+shift+,=reload_config"
      "ctrl+shift+p=toggle_command_palette"
      "ctrl+enter=toggle_fullscreen"
      "ctrl+shift+j=write_screen_file:paste"
      "ctrl+shift+alt+j=write_screen_file:open"
    ];
  in {
    config = {
      programs.ghostty = {
        enable = true;
        package = null;
        enableFishIntegration = true;
        systemd.enable = false;
        settings =
          {
            keybind = unifiedKeybinds;
            window-width = 150;
            window-height = 38;
            window-save-state = "never";
            window-padding-x = 10;
            window-padding-y = 8;
            background-blur = true;
            background-opacity = 0.96;
            font-family = "FiraCode Nerd Font Mono";
            font-size = 14;
            term = "xterm-256color";
            window-inherit-font-size = false;
          }
          // lib.optionalAttrs isDarwin {
            macos-titlebar-style = "transparent";
          };
      };

      catppuccin.ghostty.enable = true;
    };
  };
}
