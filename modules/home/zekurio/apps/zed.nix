{lib, ...}: {
  # Config/theme only; the binary comes from the host. Follow the system
  # appearance while retaining the global blue accent.
  programs.zed-editor = {
    enable = true;
    package = null;
    userSettings.theme = {
      mode = "system";
      light = lib.mkForce "Catppuccin Latte (blue)";
      dark = lib.mkForce "Catppuccin Frappé (blue)";
    };
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
}
