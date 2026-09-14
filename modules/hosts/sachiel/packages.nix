{
  flake.modules.darwin.sachiel = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [
      openssh
      python3
      uv
    ];
  };
}
