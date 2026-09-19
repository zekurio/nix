{
  flake.modules.homeManager.zekurio = {pkgs, ...}: {
    home.packages = with pkgs; [
      age
      devenv
      envsubst
      gh
      git
      git-lfs
      jujutsu
      jq
      nil
      nixd
      nodejs
      ripgrep
      sops
    ];
  };
}
