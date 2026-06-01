{
  config,
  inputs,
  lib,
  ...
}: let
  cfg = config.services.homelab.hermes-agent;
in {
  imports = [
    inputs.hermes-agent.nixosModules.default
  ];

  options.services.homelab.hermes-agent = {
    enable = lib.mkEnableOption "Hermes Agent Discord gateway";
  };

  config = lib.mkIf cfg.enable {
    services.hermes-agent = {
      enable = true;
      environmentFiles = [config.sops.secrets.hermes_env.path];
      # Enables the Discord gateway support
      extraDependencyGroups = ["messaging"];
      # Exposes the hermes CLI + shared HERMES_HOME system-wide so we can run
      # `hermes auth` on the server (codex OAuth) after the first deploy.
      addToSystemPackages = true;
      settings = {
        model = {
          default = "gpt-5.5";
          provider = "openai-codex";
        };
        # Reasoning effort for the Codex Responses API.
        # Valid: "none" | "minimal" | "low" | "medium" | "high" | "xhigh".
        agent.reasoning_effort = "high";
        toolsets = ["all"];
      };
    };

    sops.secrets.hermes_env = {
      mode = "0400";
    };
  };
}
