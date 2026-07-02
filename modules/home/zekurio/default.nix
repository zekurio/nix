{
  lib,
  pkgs,
  ...
}: let
  homeDirectory =
    if pkgs.stdenv.hostPlatform.isDarwin
    then "/Users/zekurio"
    else "/home/zekurio";
in {
  imports = [
    ./cli
    ./git
    ./pi
  ];

  config = {
    home.pi = {
      enable = true;
      settings = {
        theme = "dark";
        quietStartup = true;
        enableInstallTelemetry = false;
        defaultProvider = "openai-codex";
        defaultModel = "gpt-5.5";
        defaultThinkingLevel = "high";
        enabledModels = [
          "anthropic/claude-fable-5"
          "anthropic/claude-opus-4-8"
          "anthropic/claude-sonnet-5"
          "openai-codex/gpt-5.5"
        ];
        packages = [
          "git:github.com/mjakl/pi-kagi-api"
          "git:github.com/Michaelliv/pi-dynamic-workflows"
          "git:github.com/tintinweb/pi-subagents"
          "https://github.com/gotgenes/pi-anthropic-auth"
          "https://github.com/tmonk/pi-goal-x"
        ];
        extensions = [
          "./extensions/fast.ts"
        ];
      };
      keybindings = {
        "app.clipboard.pasteImage" = [
          "ctrl+v"
          "alt+v"
        ];
        "app.thinking.cycle" = ["ctrl+r"];
        "tui.editor.cursorRight" = ["right"];
      };
      contextFiles."extensions/fast.ts" = builtins.readFile ./pi/extensions/fast.ts;
    };

    home = {
      username = lib.mkDefault "zekurio";
      homeDirectory = lib.mkDefault homeDirectory;
      stateVersion = lib.mkDefault "25.05";
      enableNixpkgsReleaseCheck = lib.mkDefault false;
      sessionPath = [
        "$HOME/.local/bin"
      ];
      sessionVariables = {
        SOPS_AGE_KEY_FILE = "${homeDirectory}/.config/sops/age/keys.txt";
      };
    };

    fonts.fontconfig.enable = false;
  };
}
