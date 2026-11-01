{inputs, ...}: let
  instructions = ''
    This machine is managed with Nix. When a command is missing, use
    `nix run nixpkgs#<pkg> -- <args>` or `nix shell nixpkgs#<pkg> -c <cmd>`.
    In a project with a `flake.nix`, `nix develop -c <cmd>` provides its toolchain.
  '';
in {
  imports = [inputs.agent-stuff.homeManagerModules.default];

  # Links the skills into ~/.agents/skills, which pi reads beside its own
  # directory, and registers the package in ~/.pi/agent/settings.json so pi
  # loads its extensions. llm-agents' wrapper already sets
  # PI_SKIP_VERSION_CHECK, so pi never suggests a self-update over the Nix
  # build.
  programs.agent-stuff.enable = true;

  home.file.".pi/agent/AGENTS.md".text = instructions;
}
