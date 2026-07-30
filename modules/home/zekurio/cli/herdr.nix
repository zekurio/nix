{
  flake.modules.homeManager.zekurio = {
    inputs,
    lib,
    osConfig,
    pkgs,
    ...
  }: {
    # Ramiel is a small public edge VM; keep this interactive tool on the Mac
    # and adam rather than compiling and installing it on the edge.
    home.packages =
      lib.optional (
        !pkgs.stdenv.hostPlatform.isLinux || osConfig.networking.hostName != "ramiel"
      )
      inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.default;
  };
}
