{
  flake.modules.nixos.adam.boot = {
    kernelParams = ["consoleblank=60"];
    loader = {
      timeout = 0;
      efi.canTouchEfiVariables = true;
      systemd-boot.enable = true;
    };
  };
}
