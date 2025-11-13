{ pkgs
, ...
}: {
  config = {
    nix.settings.trusted-users = [ "zekurio" ];

    environment.shells = with pkgs; [ fish bashInteractive ];
    environment.variables.EDITOR = "vim";

    programs.fish.enable = true;
    programs.nix-ld.enable = true;

    users = {
      users = {
        zekurio = {
          shell = pkgs.fish;
          uid = 1000;
          isNormalUser = true;
          hashedPassword = "$y$j9T$F7RSP23wOrzzmEJcTxY98.$i58fRl1nIbPjOZ4jBxLu/FWJb/i/DEytiWVtMxcd5G8";
          extraGroups = [
            "wheel"
            "users"
            "video"
            "podman"
            "input"
          ];
          group = "zekurio";
          openssh = {
            authorizedKeys.keys = [
              "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOCcQoZiY9wkJ+U93isE8B3CKLmzL7TPzVh3ugE1WPJq"
            ];
          };
        };
      };
      groups = {
        zekurio = {
          gid = 1000;
        };
      };
    };
  };
}
