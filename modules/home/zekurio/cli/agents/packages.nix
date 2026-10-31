{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  cfg = config.agents;
  inherit (pkgs.stdenv.hostPlatform) isLinux system;
  llmAgents = inputs.llm-agents.packages.${system};

  clis = [
    llmAgents.claude-code
    llmAgents.codex
  ];

  # Tools agents reach for first; without them they fail and retry via `nix run`.
  tools = [
    pkgs.fd
    pkgs.file
    pkgs.python3
    pkgs.sqlite
  ];
in {
  options.agents = {
    desktop = lib.mkEnableOption "the T3 Code desktop app";

    t3code = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      # providerPackages replaces llm-agents' default providers, which would
      # otherwise put every agent it packages on T3 Code's PATH. GUI launches
      # and systemd services do not inherit the interactive shell PATH, so
      # it carries the tools as well.
      default = llmAgents.t3code.override {
        providerPackages =
          [
            pkgs.git
            pkgs.gh
            pkgs.openssh
          ]
          ++ clis
          ++ tools;
      };
      description = "T3 Code with the agent CLIs on its PATH, for the desktop app and adam's server.";
    };
  };

  config.home.packages =
    clis
    ++ tools
    # macOS gets T3 Code from Homebrew.
    ++ lib.optional isLinux cfg.t3code
    # llm-agents' t3code-desktop wraps the default build, so take the
    # desktop output of this one instead.
    ++ lib.optional cfg.desktop cfg.t3code.desktop;
}
