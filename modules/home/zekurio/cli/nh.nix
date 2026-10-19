{
  flake.modules.homeManager.zekurio = {config, ...}: {
    # nh evaluates as the user and only elevates for activation, so a plain
    # git flake works without the `path:` workaround root needs for a
    # user-owned checkout. Garbage collection stays with nix.gc.
    programs.nh = {
      enable = true;
      flake = "${config.home.homeDirectory}/Git/nix";
    };
  };
}
