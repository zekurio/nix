{
  config,
  lib,
  ...
}: {
  # Zed, Claude Code and Codex send their requests to vrouter once the
  # machine has a client key. Each reads the key with a command or wrapper
  # instead of a variable: T3 Code and other GUI launches never see shell
  # variables, and the key stays out of the store.
  options.agents.vrouter = {
    url = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = "https://vrouter.zekurio.me";
      description = "vrouter origin. Anthropic clients append /v1/messages themselves; OpenAI clients need /v1.";
    };

    # Issued on vrouter's API keys page, one per machine. It is placed by
    # hand except on adam, which takes it from sops.
    keyFile = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/.config/vrouter/api-key";
      description = "vrouter client key for this machine.";
    };
  };
}
