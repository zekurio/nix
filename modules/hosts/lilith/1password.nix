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
        file = {
          ".config/1Password/ssh/agent.toml".text = ''
            [[ssh-keys]]
            item = "zekurio@lilith"
          '';

          # 1Password only installs its native-messaging manifest for known
          # Chromium variants; Helium uses its own profile directory.
          ".config/net.imput.helium/NativeMessagingHosts/com.1password.1password.json" = {
            force = true;
            source =
              config.lib.file.mkOutOfStoreSymlink
              "${config.home.homeDirectory}/.config/chromium/NativeMessagingHosts/com.1password.1password.json";
          };
        };
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
