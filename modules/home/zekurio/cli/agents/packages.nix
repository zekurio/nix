{inputs, ...}: {
  perSystem = {system, ...}: let
    pkgs = import inputs.nixpkgs-unstable {inherit system;};
    inherit (pkgs) lib;
    inherit (pkgs.stdenv.hostPlatform) isLinux;
    llmAgents = inputs.llm-agents.packages.${system};
    t3code = inputs.t3code-nightly.packages.${system};

    clis = [
      llmAgents.claude-code
      llmAgents.codex
      llmAgents.opencode
    ];

    # GUI launches and systemd services do not inherit the interactive shell PATH.
    extraRuntimePackages =
      [
        pkgs.git
        pkgs.gh
        pkgs.openssh
      ]
      ++ clis;
    server = t3code.t3code.override {inherit extraRuntimePackages;};
    desktop = t3code.t3code-desktop.override {inherit extraRuntimePackages;};
  in {
    # The agents profile points at one of these environments; see profile.nix.
    packages =
      {
        # macOS gets T3 Code from Homebrew.
        agents = pkgs.buildEnv {
          name = "agents";
          paths = clis ++ lib.optional isLinux server;
        };
      }
      // lib.optionalAttrs isLinux {
        agents-desktop = pkgs.buildEnv {
          name = "agents-desktop";
          paths = clis ++ [server desktop];
        };
      };
  };
}
