{lib, ...}: {
  # Hosts enable kitty themselves; macOS uses Ghostty.
  programs.kitty.settings = {
    font_family = "FiraCode Nerd Font";
    font_size = 12;
    # Remote hosts rarely ship kitty's terminfo; Ghostty made the same call.
    term = "xterm-256color";
    update_check_interval = 0;

    initial_window_width = "150c";
    initial_window_height = "38c";
    remember_window_size = false;
    window_padding_width = "8 10";
    # Hosts tune the opacity to their compositor's blur.
    background_opacity = lib.mkDefault 0.96;
    # Any positive value turns on the Wayland background blur extension.
    background_blur = 1;
    hide_window_decorations = true;

    # splits allows free vertical and horizontal splits; stack zooms one.
    enabled_layouts = "splits,stack";

    # Flat tabs: inactive titles sit on the terminal background and only the
    # active tab gets a block of colour, set in the theme. The side margin
    # keeps the first tab clear of rounded window corners.
    tab_bar_edge = "top";
    tab_bar_style = "separator";
    tab_separator = ''""'';
    tab_title_template = ''" {bell_symbol}{index} {title} "'';
    tab_title_max_length = 32;
    tab_bar_margin_width = 6;
    tab_bar_margin_height = "4 2";
    active_tab_font_style = "bold";
    inactive_tab_font_style = "normal";
  };
}
