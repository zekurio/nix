{
  # Puts the agents profile's bin, desktop entries and completions on the
  # session paths. modules/home/zekurio/cli/agents/profile.nix manages the
  # profile at this same path below the home directory.
  environment.profiles = ["$HOME/.local/state/nix/profiles/agents"];
}
