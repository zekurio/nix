{
  self,
  inputs,
  ...
}: {
  perSystem = {system, ...}: let
    pkgs = import inputs.nixpkgs-unstable {inherit system;};
    adam = self.nixosConfigurations.adam.config;
    budget = adam.systemd.slices.nix-build.sliceConfig;
  in {
    checks.adam-build-safety = assert adam.nix.settings.max-jobs == 1;
    assert adam.nix.settings.cores == 2;
    assert adam.nix.settings.build-dir == "/var/lib/nix-build";
    assert adam.fileSystems."/".fsType == "ext4";
    assert builtins.any (swap: swap.device == "/var/lib/swapfile" && swap.size == 16384) adam.swapDevices;
    assert budget.MemoryHigh == "3G" && budget.MemoryMax == "4G" && budget.MemorySwapMax == "4G";
    assert budget.CPUQuota == "200%";
    assert adam.systemd.services.nix-daemon.serviceConfig.Slice == "nix-build.slice";
    assert adam.systemd.services.nixos-upgrade.serviceConfig.Slice == "nix-build.slice";
    assert adam.systemd.services.nixos-upgrade.environment.NIX_REMOTE == "daemon";
    assert !adam.system.autoUpgrade.allowReboot;
      pkgs.runCommand "adam-build-safety" {} "touch $out";
  };
}
