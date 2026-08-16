{...}: {
  flake.modules.nixos.lilith = {...}: let
    username = "zekurio";
  in {
    programs._1password-gui = {
      enable = true;
      polkitPolicyOwners = [username];
    };

    # Permit 1Password's browser integration to connect to Helium.
    environment.etc."1password/custom_allowed_browsers".text = ''
      helium
    '';

    home-manager.users.${username} = {
      config,
      lib,
      ...
    }: let
      agentSocket = "${config.home.homeDirectory}/.1password/agent.sock";
    in {
      home = {
        sessionVariables.SSH_AUTH_SOCK = agentSocket;
        file.".config/1Password/ssh/agent.toml".text = ''
          [[ssh-keys]]
          item = "zekurio@lilith"
        '';
      };

      programs.ssh.settings = {
        "*" = {
          AddKeysToAgent = lib.mkForce "no";
          IdentityAgent = agentSocket;
          IdentityFile = "none";
        };
        "github.com" = {
          AddKeysToAgent = lib.mkForce "no";
          IdentityFile = lib.mkForce null;
        };
        adam.IdentityFile = lib.mkForce null;
        ramiel.IdentityFile = lib.mkForce null;
      };
    };
  };
}
