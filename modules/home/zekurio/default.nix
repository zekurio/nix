# Home Manager's NixOS and nix-darwin modules set the username and home
# directory from users.users.
{
  config,
  lib,
  ...
}: {
  config = {
    home = {
      stateVersion = lib.mkDefault "25.05";
      enableNixpkgsReleaseCheck = lib.mkDefault false;
      sessionPath = [
        "$HOME/.local/bin"
      ];
      sessionVariables = {
        SOPS_AGE_KEY_FILE = "${config.xdg.configHome}/sops/age/keys.txt";
      };
    };

    fonts.fontconfig.enable = false;
  };
}
