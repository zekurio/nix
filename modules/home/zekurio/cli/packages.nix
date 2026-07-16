{
  flake.modules.homeManager.zekurio = {pkgs, ...}: {
    home.packages = with pkgs; [
      age
      bitwarden-cli
      bun
      devenv
      envsubst
      gh
      git
      git-lfs
      jujutsu
      jq
      nil
      nixd
      ripgrep
      sops
    ];
  };
}
