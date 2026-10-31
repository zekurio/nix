{config, ...}: {
  # The vrouter client key for the agents and T3 Code, which run as zekurio.
  # agents.vrouter in the Home Manager profile reads it from here instead of
  # a hand-placed file.
  sops.secrets.agents_vrouter_api_key = {
    owner = "zekurio";
    mode = "0400";
  };

  home-manager.users.zekurio.agents.vrouter.keyFile = config.sops.secrets.agents_vrouter_api_key.path;
}
