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
    llmAgents.codex
  ];

  # Tools agents reach for first; without them they fail and retry via `nix run`.
  tools = [
    pkgs.fd
    pkgs.file
    pkgs.python3
    pkgs.sqlite
  ];

  # Codex fetches its model list from the provider, but vrouter answers in
  # OpenAI's format instead of Codex's catalog format, so Codex falls back
  # to the catalog built into it. That one offers models vrouter refuses and
  # hides Daybreak Blue. This copy, from the same Codex source, keeps the
  # models enabled in vrouter's OpenAI section; keep the list in sync with
  # them. modules/home/zekurio/cli/agents/vrouter.nix points Codex at it.
  codexModels =
    pkgs.runCommand "codex-models" {
      nativeBuildInputs = [pkgs.jq];
      allowed = builtins.toJSON [
        "gpt-daybreak-blue-latest"
        "gpt-6-astra"
        "gpt-6-luna"
        "gpt-6-sol"
        "gpt-6.1-terra"
        "gpt-6.1-sol"
      ];
    } ''
      install -d $out/share/codex
      jq --argjson allowed "$allowed" \
        '.models |= map(select(.slug | IN($allowed[])) | .visibility = "list")' \
        ${llmAgents.codex.src}/codex-rs/models-manager/models.json > $out/share/codex/models.json
    '';
  profile = clis ++ tools ++ [codexModels];

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
      paths = profile ++ lib.optional isLinux server;
    };
  }
  // lib.optionalAttrs isLinux {
    agents-desktop = pkgs.buildEnv {
      name = "agents-desktop";
      paths = profile ++ [server desktop];
    };
  }
