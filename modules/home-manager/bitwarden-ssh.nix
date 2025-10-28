{
  lib,
  config,
  ...
}: let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.modules.homeManager.bitwardenSsh;
in {
  options.modules.homeManager.bitwardenSsh = {
    enable = mkEnableOption "Bitwarden SSH agent socket configuration";
  };

  config = mkIf cfg.enable {
    home-manager.users.zekurio.home.sessionVariables = {
      SSH_AUTH_SOCK = "$HOME/.bitwarden-ssh-agent.sock";
    };
  };
}
