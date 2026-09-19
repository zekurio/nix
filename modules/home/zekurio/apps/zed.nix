{
  flake.modules.homeManager.zekurio = {lib, ...}: {
    # Config/theme only; the binary comes from the host.
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
      userSettings.theme = lib.mkForce {
        light = "Catppuccin Latte (blue)";
        dark = "Catppuccin Frappé (blue)";
      };
    };

    catppuccin.zed = {
      enable = true;
      icons.enable = true;
    };
  };
}
