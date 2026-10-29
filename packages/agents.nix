# The agents profile points at one of these environments; see
# modules/home/zekurio/cli/agents/profile.nix.
{
  inputs,
  pkgs,
}: let
  inherit (pkgs) lib;
  inherit (pkgs.stdenv.hostPlatform) isLinux system;
  llmAgents = inputs.llm-agents.packages.${system};

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
  # providerPackages replaces llm-agents' default providers, which would
  # otherwise put every agent it packages on T3 Code's PATH. Its
  # t3code-desktop package wraps the default build, so take the desktop
  # output of this one instead.
  t3code = llmAgents.t3code.override {providerPackages = extraRuntimePackages;};
  server = t3code;
  desktop = t3code.desktop;
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
