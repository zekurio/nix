{config, ...}: {
  services.displayManager.dux-greeter = {
    enable = true;
    compositor.name = "niri";
    # greetd copies the shell's settings, colours and wallpaper from here
    # whenever it starts, so the login screen matches the session.
    configHome = config.users.users.zekurio.home;
  };
}
