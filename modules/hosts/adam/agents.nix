{config, ...}: {
  # The vrouter client key and the Firecrawl key for pi and T3 Code, which
  # run as zekurio. agents.vrouter and agents.firecrawl in the Home Manager
  # profile read them from here instead of hand-placed files. Blitzcrank
  # reads the same Firecrawl key through its env template, which sops renders
  # as root, so owning the file as zekurio does not lock it out.
  sops.secrets = {
    agents_vrouter_api_key = {
      owner = "zekurio";
      mode = "0400";
    };
    firecrawl_api_key = {
      owner = "zekurio";
      mode = "0400";
    };
  };

  home-manager.users.zekurio.agents = {
    # Emulators that T3 Code starts run inside t3code.service and count
    # against its memory limits.
    android.enable = true;
    vrouter.keyFile = config.sops.secrets.agents_vrouter_api_key.path;
    firecrawl.keyFile = config.sops.secrets.firecrawl_api_key.path;
  };
}
