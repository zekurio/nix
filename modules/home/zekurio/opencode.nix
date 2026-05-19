{
  inputs,
  pkgs,
  ...
}: let
  opencode = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode;
in {
  home.packages = [opencode];

  xdg.configFile."opencode/opencode.json".text = builtins.toJSON {
    "$schema" = "https://opencode.ai/config.json";
    autoupdate = false;
    plugin = ["opencode-direnv"];
    server = {
      hostname = "0.0.0.0";
      port = 4096;
    };
  };

  systemd.user.services.opencode-web = {
    Unit = {
      Description = "OpenCode web server";
      After = ["network-online.target"];
      Wants = ["network-online.target"];
    };

    Service = {
      ExecStart = "${opencode}/bin/opencode web --hostname 0.0.0.0 --port 4096";
      Restart = "on-failure";
      RestartSec = 5;
      WorkingDirectory = "%h";
    };

    Install.WantedBy = ["default.target"];
  };
}
