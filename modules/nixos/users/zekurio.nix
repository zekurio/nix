{
  inputs,
  pkgs,
  ...
}: let
  username = "zekurio";
  githubAuthorizedKeys = pkgs.fetchurl {
    url = "https://github.com/zekurio.keys";
    hash = "sha256-Xgu1iDB36YDwJihDLUg1gNzn+60tVdS00qkEsAo/Fqk=";
  };
in {
  nix.settings.trusted-users = [username];

  programs = {
    fish.enable = true;
    vim = {
      enable = true;
      defaultEditor = true;
    };
  };

  environment.shells = [pkgs.fish];

  users = {
    defaultUserShell = pkgs.fish;

    users.${username} = {
      shell = pkgs.fish;
      uid = 1000;
      isNormalUser = true;
      hashedPassword = "$y$j9T$WeZ0opXmn8yWxOwDH6/bL0$wtARyV6xTpo4OYgGpy9W0EAhJtJPYWXlwqaaVsfZQN/";
      extraGroups = [
        "wheel"
        "users"
        "video"
        "podman"
        "input"
        "i2c"
      ];
      group = username;
      openssh.authorizedKeys.keyFiles = [githubAuthorizedKeys];
    };

    groups.${username}.gid = 1000;
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    extraSpecialArgs = {inherit inputs;};

    users.${username}.imports = [
      ../../home/zekurio
    ];
  };
}
