{
  inputs,
  lib,
  pkgs,
  ...
}: let
  omp = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.omp;
in {
  config = lib.mkIf (!pkgs.stdenv.hostPlatform.isDarwin) {
    systemd.user.services.claude-omp-hourly = {
      Unit.Description = "Hourly Claude model trigger through OMP";

      Service = {
        Type = "oneshot";
        WorkingDirectory = "%h";
        TimeoutStartSec = "2m";
        ExecStart = "${omp}/bin/omp --allow-home -p --no-session --model claude-sonnet-4-5 --thinking=minimal --max-time=60 hi";
      };
    };

    systemd.user.timers.claude-omp-hourly = {
      Unit.Description = "Run the hourly Claude OMP trigger";

      Timer = {
        OnCalendar = "hourly";
        Persistent = true;
        Unit = "claude-omp-hourly.service";
      };

      Install.WantedBy = ["timers.target"];
    };
  };
}
