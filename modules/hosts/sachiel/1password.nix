{...}: {
  flake.modules.darwin.sachiel = {...}: let
    username = "zekurio";
  in {
    home-manager.users.${username} = {
      config,
      lib,
      ...
    }: let
      agentSocket = "${config.home.homeDirectory}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock";
    in {
      home = {
        sessionVariables.SSH_AUTH_SOCK = agentSocket;
        file.".config/1Password/ssh/agent.toml".text = ''
          [[ssh-keys]]
          item = "zekurio@sachiel"
        '';
      };

      programs.ssh.settings = {
        "*" = {
          AddKeysToAgent = lib.mkForce "no";
          # OpenSSH splits unquoted paths at spaces.
          IdentityAgent = ''"${agentSocket}"'';
          IdentityFile = "none";
        };
        "github.com" = {
          AddKeysToAgent = lib.mkForce "no";
          IdentityFile = lib.mkForce null;
        };
        adam.IdentityFile = lib.mkForce null;
      };
    };
  };
}
