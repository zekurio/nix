{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  cfg = config.agents.vrouter;
  inherit (pkgs.stdenv.hostPlatform) isDarwin isLinux system;
  inherit (inputs.llm-agents.packages.${system}) codex;
  python = pkgs.python3.withPackages (ps: [ps.tomli-w]);

  settings = {
    # flake.lock moves the CLI; Codex's own updater cannot replace a store
    # path.
    check_for_update_on_startup = false;
  };

  # A custom provider, because built-in openai only takes a catalog from
  # ChatGPT's hosts. Codex runs the command for a bearer token, so a stored
  # ChatGPT login stays but goes unused, and no login screen shows. It reruns
  # the command every five minutes and after a 401.
  provider = {
    name = "vrouter";
    base_url = cfg.url + "/v1";
    wire_api = "responses";
    auth = {
      command = lib.getExe' pkgs.coreutils "cat";
      args = [cfg.keyFile];
    };
  };

  # The catalog this Codex release ships, which the sync takes each model's
  # tools, instructions and limits from.
  bundled = pkgs.runCommand "codex-bundled-models.json" {} ''
    export HOME=$TMPDIR CODEX_HOME=$TMPDIR/codex
    mkdir -p "$CODEX_HOME"
    ${lib.getExe codex} debug models --bundled > $out
  '';

  # Codex fetches <base_url>/models only in its own catalog format, which
  # vrouter's /v1/models lacks, and otherwise offers its bundled models,
  # some of which vrouter refuses. The sync builds that catalog from
  # vrouter's list instead and points model_catalog_json at it; Codex then
  # offers only those models. Codex reads the file at startup.
  sync = pkgs.writeShellApplication {
    name = "codex-vrouter-models";
    text = ''
      exec env PYTHONDONTWRITEBYTECODE=1 ${lib.getExe python} ${./codex-config.py} \
        --config "$HOME/.codex/config.toml" \
        --settings ${lib.escapeShellArg (builtins.toJSON settings)} \
        --provider-id vrouter \
        --provider ${lib.escapeShellArg (builtins.toJSON provider)} \
        --key-file ${lib.escapeShellArg cfg.keyFile} \
        --url ${lib.escapeShellArg cfg.url} \
        --catalog "$HOME/.codex/vrouter-models.json" \
        --bundled ${bundled} \
        "$@"
    '';
  };
in {
  home.packages = [sync];

  # Without a key the provider and catalog come out again and Codex falls
  # back to its own login. A failed fetch keeps the last catalog.
  home.activation.codexConfig = lib.hm.dag.entryAfter ["writeBoundary"] ''
    run ${lib.getExe sync} || warnEcho "Could not sync Codex's vrouter models; leaving its config unchanged."
  '';

  systemd.user = lib.mkIf isLinux {
    services.codex-vrouter-models = {
      Unit.Description = "Sync Codex's models from vrouter";
      Service = {
        Type = "oneshot";
        ExecStart = lib.getExe sync;
      };
    };
    timers.codex-vrouter-models = {
      Unit.Description = "Refresh Codex's vrouter model list";
      Timer = {
        OnStartupSec = "1min";
        OnUnitActiveSec = "15min";
      };
      Install.WantedBy = ["timers.target"];
    };
  };

  launchd.agents.codex-vrouter-models = lib.mkIf isDarwin {
    enable = true;
    config = {
      ProgramArguments = [(lib.getExe sync)];
      RunAtLoad = true;
      StartInterval = 900;
      ProcessType = "Background";
    };
  };
}
