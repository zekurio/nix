{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.homelab.hermes-agent;
in {
  imports = [
    inputs.hermes-agent.nixosModules.default
  ];

  options.services.homelab.hermes-agent = {
    enable = lib.mkEnableOption "Hermes Agent Discord gateway";
  };

  config = lib.mkIf cfg.enable {
    services.hermes-agent = {
      enable = true;
      environmentFiles = [config.sops.secrets.hermes_env.path];
      # Non-secret env (written to $HERMES_HOME/.env). Discord allowlist:
      # only these user IDs may interact with the bot. Numeric IDs avoid
      # needing the privileged "members" intent.
      environment = {
        DISCORD_ALLOWED_USERS = "144853050761150465"; # zekurio
      };
      # Enables the Discord gateway support
      extraDependencyGroups = ["messaging"];
      # Exposes the hermes CLI + shared HERMES_HOME system-wide so we can run
      # `hermes auth` on the server (codex OAuth) after the first deploy.
      addToSystemPackages = true;
      settings = {
        model = {
          default = "gpt-5.5";
          provider = "openai-codex";
        };
        # Reasoning effort for the Codex Responses API.
        # Valid: "none" | "minimal" | "low" | "medium" | "high" | "xhigh".
        agent.reasoning_effort = "high";
        toolsets = ["all"];
      };
    };

    sops.secrets.hermes_env = {
      mode = "0400";
    };

    # Discord voice playback needs libopus. discord.py loads it via
    # ctypes.util.find_library("opus"), which in the locked-down service only
    # resolves when libopus is on LD_LIBRARY_PATH (so dlopen finds it) *and*
    # `ld` (binutils) is on PATH (so find_library returns the soname).
    # Verified on adam: find_library -> "libopus.so.0", load_opus -> loaded.
    # Scoped to the service so the interactive hermes user stays clean.
    systemd.services.hermes-agent = {
      path = [pkgs.binutils];
      environment.LD_LIBRARY_PATH = lib.makeLibraryPath [pkgs.libopus];
    };
  };
}
