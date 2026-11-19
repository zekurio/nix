{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.agents.vrouter;
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
  #
  # Command auth also makes Codex fetch <base_url>/models at startup. It
  # wants Codex's own catalog format, {"models": [...]}, which vrouter's
  # /v1/models lacks, so the fetch fails into Codex's log and /model offers
  # Codex's bundled catalog. vrouter routes any model it serves; one missing
  # from the catalog runs with Codex's fallback metadata. Once vrouter's list
  # carries `models`, set model_catalog_url to its /v1/models so /model shows
  # only what it serves.
  provider = {
    name = "vrouter";
    base_url = cfg.url + "/v1";
    wire_api = "responses";
    auth = {
      command = lib.getExe' pkgs.coreutils "cat";
      args = [cfg.keyFile];
    };
  };
in {
  # Without a key the provider comes out again and Codex falls back to its
  # own login.
  home.activation.codexConfig = lib.hm.dag.entryAfter ["writeBoundary"] ''
    provider=()
    if [ -s ${lib.escapeShellArg cfg.keyFile} ]; then
      provider=(--provider ${lib.escapeShellArg (builtins.toJSON provider)})
    fi
    run env PYTHONDONTWRITEBYTECODE=1 ${lib.getExe python} ${./codex-config.py} \
      --config "$HOME/.codex/config.toml" \
      --settings ${lib.escapeShellArg (builtins.toJSON settings)} \
      --provider-id vrouter \
      "''${provider[@]}"
  '';
}
