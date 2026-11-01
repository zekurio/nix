{
  config,
  lib,
  ...
}: {
  # agent-stuff's web_search and web_extract tools stay off until pi sees
  # FIRECRAWL_API_KEY. packages.nix wraps pi to read it from this file, since
  # T3 Code and other GUI launches never see shell variables. The key is
  # placed by hand except on adam, which takes it from sops; it stays out of
  # the store. Without it the tools stay off and pi warns at startup.
  options.agents.firecrawl.keyFile = lib.mkOption {
    type = lib.types.str;
    default = "${config.home.homeDirectory}/.config/firecrawl/api-key";
    description = "Firecrawl API key for pi's web tools.";
  };
}
