{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.agents.vrouter;
  json = builtins.toJSON;

  # Points pi's built-in anthropic and openai providers at vrouter and keeps
  # only the models vrouter's /v1/models lists, with pi's own catalog
  # metadata for them. A models.json entry could only redirect the
  # providers: models there add to the catalog, and /model would offer every
  # model pi knows for both. Registering a provider with `models` from an
  # extension replaces its list instead.
  #
  # The extension does nothing without the key file, so pi stays on its
  # /login credentials until the machine has a key. A stored login outranks
  # the key and would be sent to vrouter, which rejects it, so log out of both
  # providers once the key is in place. pi runs the `!` command on every
  # request, so a replaced key needs no restart; the model list is read once
  # per pi start.
  #
  # supportsStrictTools is off because Anthropic rejects pi's strict built-in
  # tools next to its non-strict __pi_deferred_placeholder__ tool ("compiled
  # grammar is too large"). pi then resends every turn non-strict, which
  # costs a round trip and a second upload of the whole context.
  providers = [
    {
      id = "anthropic";
      baseUrl = cfg.url;
      compat.supportsStrictTools = false;
    }
    {
      id = "openai";
      baseUrl = cfg.url + "/v1";
      compat = {};
    }
  ];

  apiKey = "!${lib.getExe' pkgs.coreutils "cat"} ${lib.escapeShellArg cfg.keyFile}";

  # T3 Code runs pi with --no-extensions for titles, branch names and commit
  # messages, so the extension never loads there and pi finds no model.
  # models.json redirects the same providers without an extension. When the
  # extension does load, its model list replaces the catalog as before.
  modelsJson = builtins.toJSON {
    providers = lib.listToAttrs (map (p: {
        name = p.id;
        value = {inherit (p) baseUrl compat;} // {inherit apiKey;};
      })
      providers);
  };

  extension = pkgs.writeText "vrouter.ts" ''
    import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
    import { getModel, getModels } from "@earendil-works/pi-ai";
    import { readFileSync } from "node:fs";

    const url = ${json cfg.url};
    const keyFile = ${json cfg.keyFile};
    const apiKey = ${json apiKey};

    // Only the OpenAI base URL ends in /v1; the Anthropic client appends
    // /v1/messages itself.
    const providers = ${json providers};

    // gpt-6.2-sol splits into family "gpt-sol" and version [6, 2],
    // claude-opus-5-5 into "claude-opus" and [5, 5].
    function parse(id: string) {
      const parts = id.split("-");
      const version = parts.filter((p) => /^\d+(\.\d+)*$/.test(p)).flatMap((p) => p.split(".").map(Number));
      return { family: parts.filter((p) => !/^\d+(\.\d+)*$/.test(p)).join("-"), version };
    }
    function newer(a: number[], b: number[]) {
      for (let i = 0; i < Math.max(a.length, b.length); i++) {
        if ((a[i] ?? 0) !== (b[i] ?? 0)) return (a[i] ?? 0) > (b[i] ?? 0);
      }
      return false;
    }

    // vrouter can serve a model before a pi release lists it. Such a model
    // borrows the newest catalog model of its family, e.g. gpt-6.2-sol takes
    // gpt-6.1-sol's thinking levels and tool support, with vrouter's context
    // window. Usage costs then follow the stand-in until pi catches up.
    function standIn(provider: string, id: string, contextWindow: number | undefined) {
      const wanted = parse(id);
      let base: ReturnType<typeof getModels>[number] | undefined;
      for (const model of getModels(provider as never)) {
        const candidate = parse(model.id);
        if (candidate.family !== wanted.family || newer(candidate.version, wanted.version)) continue;
        if (!base || newer(candidate.version, parse(base.id).version)) base = model;
      }
      if (!base) return undefined;
      const name = base.name.replace(parse(base.id).version.join("."), wanted.version.join("."));
      return { model: { ...base, id, name, contextWindow: contextWindow ?? base.contextWindow }, base: base.id };
    }

    export default async function (pi: ExtensionAPI) {
      let key = "";
      try {
        key = readFileSync(keyFile, "utf8").trim();
      } catch {}
      if (!key) return;

      let served: Array<{ id: string; context_window?: number }> | undefined;
      const notes: string[] = [];
      try {
        const response = await fetch(url + "/v1/models", {
          headers: { authorization: "Bearer " + key },
          signal: AbortSignal.timeout(5000),
        });
        if (!response.ok) throw new Error("HTTP " + response.status);
        served = ((await response.json()) as { data: Array<{ id: string; context_window?: number }> }).data;
      } catch (error) {
        // Still route through vrouter, with the full catalog, so pi keeps
        // working while vrouter's model list is unreachable.
        notes.push("vrouter: could not list its models (" + String(error) + "), so /model shows pi's whole catalog.");
      }

      const found = new Set<string>();
      for (const provider of providers) {
        if (served === undefined) {
          pi.registerProvider(provider.id, { baseUrl: provider.baseUrl, apiKey, compat: provider.compat });
          continue;
        }
        // vrouter lists both vendors' models together; each provider keeps
        // the ones its catalog knows or has a stand-in for.
        const models = served.flatMap(({ id, context_window }) => {
          const model = getModel(provider.id as never, id as never);
          if (model) return [model];
          const borrowed = standIn(provider.id, id, context_window);
          if (!borrowed) return [];
          notes.push("vrouter: pi's catalog lacks " + id + ", so it uses " + borrowed.base + "'s metadata.");
          return [borrowed.model];
        });
        for (const model of models) found.add(model.id);
        pi.registerProvider(provider.id, {
          baseUrl: provider.baseUrl,
          apiKey,
          models: models.map((model) => ({
            ...model,
            baseUrl: provider.baseUrl,
            compat: { ...model.compat, ...provider.compat },
          })),
        });
      }

      // Only a model without a family in pi's catalog stays hidden.
      const unknown = (served ?? []).map(({ id }) => id).filter((id) => !found.has(id));
      if (unknown.length > 0) notes.push("vrouter: pi's catalog lacks " + unknown.join(", ") + ", so /model leaves them out.");
      if (notes.length > 0) pi.on("session_start", (_event, ctx) => ctx.ui.notify(notes.join("\n"), "warning"));
    }
  '';
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

  config = {
    home.file.".pi/agent/extensions/vrouter.ts".source = extension;

    # pi creates models.json itself, so merge the providers in instead of
    # owning the file. Without a key they come out again: a stored /login
    # would otherwise be sent to vrouter, the same rule the extension follows.
    home.activation.piVrouterModels = lib.hm.dag.entryAfter ["writeBoundary"] ''
      f="$HOME/.pi/agent/models.json"
      run mkdir -p "$(dirname "$f")"
      [ -s "$f" ] || run sh -c 'echo "{}" > "$1"' _ "$f"
      tmp=$(mktemp)
      if [ -s ${lib.escapeShellArg cfg.keyFile} ]; then
        filter='. * {providers: $p.providers}'
      else
        filter='.providers |= ((. // {}) | del(.anthropic, .openai))'
      fi
      ${lib.getExe pkgs.jq} --argjson p ${lib.escapeShellArg modelsJson} "$filter" "$f" > "$tmp" \
        && run chmod 600 "$tmp" && run mv "$tmp" "$f"
    '';
  };
}
