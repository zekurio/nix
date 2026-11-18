{config, ...}: let
  cfg = config.services.displayManager.dux-greeter;
  inherit (config.services.xserver) xkb;
  lua = builtins.toJSON;
in {
  services.displayManager.dux-greeter = {
    enable = true;
    compositor = {
      name = "hyprland";
      # Replaces the greeter's built-in Hyprland config, so its environment
      # variable and logo setting are repeated. The monitor rules match the
      # session's, which saves a modeset into HDR when the session starts.
      customConfig = ''
        hl.env("DMS_RUN_GREETER", "1")
        hl.config({
            misc = { disable_hyprland_logo = true, disable_splash_rendering = true },
            input = { kb_layout = ${lua xkb.layout}, kb_variant = ${lua xkb.variant}, kb_options = ${lua xkb.options}, numlock_by_default = true },
        })
        ${config.modules.hyprland.outputs}
      '';
    };
    # greetd copies the shell's settings, colours and wallpaper from here
    # whenever it starts, so the login screen matches the session.
    configHome = config.users.users.zekurio.home;
  };

  # greetd starts once per boot, so the copy above lags a wallpaper or theme
  # change until the next reboot. DMS's own `dms-greeter sync` refuses to run
  # on NixOS, so rerun the module's copy, which it keeps in greetd's
  # preStart, whenever one of the copied files changes. The greeter reads
  # the copies when it next shows, without restarting greetd.
  systemd = {
    services.dux-greeter-sync = {
      description = "Copy the Dux Shell theme to the greeter";
      serviceConfig.Type = "oneshot";
      script = config.systemd.services.greetd.preStart;
    };
    paths.dux-greeter-sync = {
      wantedBy = ["multi-user.target"];
      # Path units watch the parent directory, so files that do not exist
      # yet, such as the legacy DankMaterialShell ones, are fine.
      pathConfig.PathChanged = cfg.configFiles;
    };
  };
}
