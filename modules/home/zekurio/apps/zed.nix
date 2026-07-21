{
  flake.modules.homeManager.zekurio = {...}: {
    # Config/theme only; the binary comes from the host. Flavor and accent
    # cascade from the global Catppuccin settings.
    programs.zed-editor = {
      enable = true;
      package = null;
      extensions = [
        "astro"
        "dockerfile"
        "git-firefly"
        "html"
        "java"
        "kotlin"
        "log"
        "make"
        "nix"
        "qml"
        "sql"
        "toml"
        "xml"
      ];
    };

    catppuccin.zed = {
      enable = true;
      icons.enable = true;
    };
  };
}
