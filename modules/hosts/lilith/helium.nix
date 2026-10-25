{
  inputs,
  pkgs,
  ...
}: {
  environment.systemPackages = [inputs.helium.packages.${pkgs.stdenv.hostPlatform.system}.default];
}
