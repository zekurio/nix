{
  boot = {
    kernelParams = ["consoleblank=60"];
    loader = {
      timeout = 0;
      efi.canTouchEfiVariables = true;
      systemd-boot = {
        enable = true;
        # The editor lets anyone at the console boot with init=/bin/sh.
        editor = false;
      };
    };
  };
}
