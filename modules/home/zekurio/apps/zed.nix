{
  flake.modules.homeManager.zekurio = {
    # Config only; the binary comes from the host.
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
  };
}
