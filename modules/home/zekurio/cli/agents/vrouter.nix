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
  extension = pkgs.writeText "vrouter.ts" ''
    import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
    import { getModel } from "@earendil-works/pi-ai";
    import { readFileSync } from "node:fs";

    const url = ${json cfg.url};
    const keyFile = ${json cfg.keyFile};
    const apiKey = ${json "!${lib.getExe' pkgs.coreutils "cat"} ${lib.escapeShellArg cfg.keyFile}"};

    // Only the OpenAI base URL ends in /v1; the Anthropic client appends
    // /v1/messages itself.
    const providers = [
      { id: "anthropic", baseUrl: url, compat: { supportsStrictTools: false } },
      { id: "openai", baseUrl: url + "/v1", compat: {} },
    ];

    export default async function (pi: ExtensionAPI) {
      let key = "";
      try {
        key = readFileSync(keyFile, "utf8").trim();
      } catch {}
      if (!key) return;

      let ids: string[] | undefined;
      let warning: string | undefined;
      try {
        const response = await fetch(url + "/v1/models", {
          headers: { authorization: "Bearer " + key },
          signal: AbortSignal.timeout(5000),
        });
        if (!response.ok) throw new Error("HTTP " + response.status);
        const body = (await response.json()) as { data: Array<{ id: string }> };
        ids = body.data.map((model) => model.id);
      } catch (error) {
        // Still route through vrouter, with the full catalog, so pi keeps
        // working while vrouter's model list is unreachable.
        warning = "vrouter: could not list its models (" + String(error) + "), so /model shows pi's whole catalog.";
      }

      const found = new Set<string>();
      for (const provider of providers) {
        if (ids === undefined) {
          pi.registerProvider(provider.id, { baseUrl: provider.baseUrl, apiKey, compat: provider.compat });
          continue;
        }
        // vrouter lists both vendors' models together; each provider keeps
        // the ones its catalog knows.
        const models = ids.flatMap((id) => {
          const model = getModel(provider.id as never, id as never);
          return model ? [model] : [];
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

      // A model newer than pi's catalog stays hidden until flake.lock moves
      // pi to a release that knows it.
      const unknown = (ids ?? []).filter((id) => !found.has(id));
      if (unknown.length > 0) warning = "vrouter: pi's catalog lacks " + unknown.join(", ") + ", so /model leaves them out.";
      if (warning) pi.on("session_start", (_event, ctx) => ctx.ui.notify(warning, "warning"));
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

  config.home.file.".pi/agent/extensions/vrouter.ts".source = extension;
}
