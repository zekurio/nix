{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.agents.vrouter;
  keyFile = lib.escapeShellArg cfg.keyFile;
  cat = lib.getExe' pkgs.coreutils "cat";
in {
  options.agents.vrouter = {
    url = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = "https://vrouter.zekurio.me";
      description = "vrouter origin. Anthropic clients append /v1/messages themselves; OpenAI clients need /v1.";
    };

    # Issued on vrouter's API keys page, one per machine. It is placed by
    # hand except on adam, which takes it from sops. Every client reads it
    # with a command: T3 Code and other GUI launches never see shell
    # variables, and the key stays out of the store.
    keyFile = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/.config/vrouter/api-key";
      description = "vrouter client key for this machine.";
    };
  };

  # Redirects pi's built-in anthropic and openai providers to vrouter and
  # keeps their model catalogs. pi runs the `!` command on every request, so
  # a replaced key needs no restart. The merge waits for the key file;
  # without it pi stays on its /login credentials. A stored login outranks
  # this key and would be sent to vrouter, which rejects it, so log out of
  # both providers once the key is in place. Deleting the key later does not
  # undo the merge; README.md lists the keys to remove to go back to the
  # logins. Merge instead of owning the file, so providers added by hand
  # survive.
  config.home.activation.piVrouter = lib.hm.dag.entryAfter ["writeBoundary"] ''
    if [ -r ${keyFile} ]; then
      f="$HOME/.pi/agent/models.json"
      run mkdir -p "$(dirname "$f")"
      [ -s "$f" ] || run sh -c 'echo "{}" > "$1"' _ "$f"
      tmp=$(mktemp)
      ${lib.getExe pkgs.jq} --arg key ${lib.escapeShellArg "!${cat} ${keyFile}"} --arg url ${lib.escapeShellArg cfg.url} \
        '. * {providers: {anthropic: {baseUrl: $url, apiKey: $key}, openai: {baseUrl: "\($url)/v1", apiKey: $key}}}' "$f" > "$tmp" && run mv "$tmp" "$f"
    fi
  '';
}
