{pkgs, ...}: {
  environment.systemPackages = [pkgs.lsof];
}
