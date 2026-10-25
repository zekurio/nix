{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.homelab.atuin-ai;
  port = 8788;
  configFile = (pkgs.formats.toml {}).generate "atuin-ai.toml" {
    inherit port;
    endpoint = "${config.services.homelab.vrouter.baseUrl}/v1";
    api_key.env = "VROUTER_API_KEY";
    default_model = "sonnet";
    # Chat streams only report token usage when asked, and vrouter counts
    # tokens from that report.
    request.body.stream_options.include_usage = true;
    models = [
      {
        alias = "opus";
        name = "Claude Opus 5.5";
        description = "Most capable, slowest";
        model = "claude-opus-5-5";
      }
      {
        alias = "sonnet";
        name = "Claude Sonnet 5.5";
        description = "Balanced speed and capability";
        model = "claude-sonnet-5-5";
      }
      {
        alias = "haiku";
        name = "Claude Haiku 5.5";
        description = "Fastest";
        model = "claude-haiku-5-5";
      }
    ];
  };
in {
  options.services.homelab.atuin-ai.enable = lib.mkEnableOption "Atuin AI server backed by vrouter with Caddy integration";

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.homelab.vrouter.enable;
        message = "services.homelab.atuin-ai requires services.homelab.vrouter for model requests.";
      }
    ];

    # The Atuin CLI speaks its own chat protocol, which this server
    # translates to the chat completions requests vrouter accepts.
    virtualisation.oci-containers.containers.atuin-ai = {
      # Upstream publishes no versioned tags.
      image = "ghcr.io/atuinsh/atuin-ai-server:latest";
      pull = "newer";
      volumes = ["${configFile}:/etc/atuin-ai/config.toml:ro"];
      environmentFiles = [config.sops.secrets.atuin_ai_env.path];
      # vrouter listens on loopback only. The server binds every interface,
      # but the firewall keeps the port closed outside the host.
      extraOptions = ["--network=host"];
    };

    systemd.services."${config.virtualisation.oci-containers.backend}-atuin-ai" = {
      after = ["vrouter.service"];
      wants = ["vrouter.service"];
    };

    # Holds VROUTER_API_KEY, a vrouter client key, and AUTH_TOKEN, which
    # clients send as ai.api_token. The vhost's source range filter is not
    # authentication.
    sops.secrets.atuin_ai_env = {
      mode = "0400";
      restartUnits = ["${config.virtualisation.oci-containers.backend}-atuin-ai.service"];
    };

    services.homelab.caddy.virtualHosts.atuin-ai = {
      domain = "atuin-ai.${config.services.homelab.domains.zekurio}";
      reverseProxy = "127.0.0.1:${toString port}";
    };
  };
}
