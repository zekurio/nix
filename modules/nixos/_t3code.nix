{
  agents,
  fetchFromGitHub,
  pnpm_11,
  pkg-config,
  libsecret,
}: let
  version = "0.0.40";
  src = fetchFromGitHub {
    owner = "pingdotgg";
    repo = "t3code";
    tag = "v${version}";
    hash = "sha256-J8kXpfMfm03/DDAiWXJuANwUNDshhiUn7Lf9tV42Xfw=";
  };
  original = agents.t3code.unwrapped;
  resourceMonitor = original.resourceMonitor.overrideAttrs {
    inherit version src;
  };
  pnpmDeps = agents.fetchPnpmDeps {
    pname = "t3code";
    inherit version src;
    pnpm = pnpm_11;
    inherit (original) pnpmWorkspaces;
    fetcherVersion = 4;
    hash = "sha256-+UsoURSM4VP+CgF1fWROBEB85EuH+iJJM/xDPFigCKk=";
  };
  # The locked upstream package is still at 0.0.38. Keep this override local
  # so updating T3 does not also update every installed agent.
  unwrapped = original.overrideAttrs (old: {
    inherit version src pnpmDeps;
    nativeBuildInputs = old.nativeBuildInputs ++ [pkg-config];
    # T3 0.0.39 added a native browser-secret helper on Linux.
    buildInputs = (old.buildInputs or []) ++ [libsecret];
    preBuild = builtins.replaceStrings [old.version] [version] old.preBuild;
    installPhase =
      builtins.replaceStrings
      ["${original.resourceMonitor}"]
      ["${resourceMonitor}"]
      old.installPhase;
    passthru = old.passthru // {inherit resourceMonitor;};
    meta =
      old.meta
      // {
        changelog = "https://github.com/pingdotgg/t3code/releases/tag/v${version}";
      };
  });
in
  agents.t3code.override {
    t3code-unwrapped = unwrapped;
    providerPackages = [agents.codex];
  }
