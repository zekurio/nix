{
  # The TTY theme draws with the terminal's 16 colours. Without its own
  # background, the SSH tint shows through.
  programs.btop.settings = {
    color_theme = "TTY";
    theme_background = false;
  };
}
