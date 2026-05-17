{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.homelab.blitzcrank;
  dataDir = "/var/lib/blitzcrank";
  runtimeConfigFile = "${dataDir}/runtime-config.json";
  upstreamPackage = inputs.blitzcrank.packages.${pkgs.system}.default;
  servicePackage = pkgs.symlinkJoin {
    name = "blitzcrank-service";
    paths = [upstreamPackage];
    nativeBuildInputs = [pkgs.makeWrapper];
    postBuild = ''
      wrapProgram $out/bin/blitzcrank \
        --set-default RUNTIME_CONFIG_PATH ${runtimeConfigFile} \
        --set-default DATABASE_PATH ${dataDir}/blitzcrank.sqlite \
        --set-default AGENT_THREADS_DIR ${dataDir}/threads
    '';
  };
in {
  imports = [
    inputs.blitzcrank.nixosModules.default
  ];

  options.services.homelab.blitzcrank = {
    enable = lib.mkEnableOption "Blitzcrank Jellyseerr/Jellyfin Discord support agent";
  };

  config = lib.mkIf cfg.enable {
    services.blitzcrank = {
      enable = true;
      package = servicePackage;
      environmentFile = config.sops.secrets.blitzcrank_env.path;
      dataDir = dataDir;
      runtimeConfigFile = runtimeConfigFile;
      publicName = "blitzcrank";
      timezone = config.time.timeZone;
      automations.enable = true;
      runtime = {
        default = {
          provider = "codex-oauth";
          model = "gpt-5.5";
          reasoningEffort = "low";
        };
        discordTriage = {
          model = "gpt-5.4-mini";
          reasoningEffort = "none";
        };
      };
    };

    systemd.services.blitzcrank = {
      environment = {
        DISCORD_TRIAGE_THRESHOLD = "0.75";
        DISCORD_THREAD_ARCHIVE_MINUTES = "1440";
        DISCORD_CONTEXT_RECENT_MESSAGES = "12";
        SEERR_WEBHOOK_LISTEN_ADDR = "127.0.0.1:8080";
        SEERR_WEBHOOK_PATH = "/webhooks/seerr";
        EXA_BASE_URL = "https://api.exa.ai";
        OPENAI_BASE_URL = "https://api.openai.com/v1";
        CODEX_FAST_MODE = "false";
        AGENT_MAX_TOOL_ITERATIONS = "15";
        AGENT_RUN_TIMEOUT = "5m";
        OPENROUTER_X_TITLE = "blitzcrank";
      };
      serviceConfig.SupplementaryGroups = ["share"];
    };

    systemd.tmpfiles.rules = [
      "d ${dataDir} 0750 blitzcrank blitzcrank -"
      "d ${dataDir}/threads 0750 blitzcrank blitzcrank -"
      "f ${runtimeConfigFile} 0640 blitzcrank blitzcrank -"
    ];

    sops.secrets.blitzcrank_env = {
      owner = "blitzcrank";
      group = "blitzcrank";
      mode = "0400";
    };
  };
}
