# The agents profile points at one of these environments; see
# modules/home/zekurio/cli/agents/profile.nix.
{
  inputs,
  pkgs,
}: let
  inherit (pkgs) lib;
  inherit (pkgs.stdenv.hostPlatform) isLinux system;
  llmAgents = inputs.llm-agents.packages.${system};
  t3code = inputs.t3code-nightly.packages.${system};

  clis = [
    llmAgents.claude-code
  ];

  # Tools agents reach for first; without them they fail and retry via `nix run`.
  tools = [
    pkgs.fd
    pkgs.file
    pkgs.python3
    pkgs.sqlite
  ];

  # GUI launches and systemd services do not inherit the interactive shell PATH.
  extraRuntimePackages =
    [
      pkgs.git
      pkgs.gh
      pkgs.openssh
    ]
    ++ clis
    ++ tools;
  server = t3code.t3code.override {inherit extraRuntimePackages;};
  desktop = t3code.t3code-desktop.override {inherit extraRuntimePackages;};
in
  {
    # macOS gets T3 Code from Homebrew.
    agents = pkgs.buildEnv {
      name = "agents";
      paths = clis ++ tools ++ lib.optional isLinux server;
    };
  }
  // lib.optionalAttrs isLinux {
    agents-desktop = pkgs.buildEnv {
      name = "agents-desktop";
      paths = clis ++ tools ++ [server desktop];
    };
  }
