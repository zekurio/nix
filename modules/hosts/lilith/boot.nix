{inputs, ...}: {
  flake.modules.nixos.lilith = {pkgs, ...}: {
    imports = [inputs.catppuccin.nixosModules.catppuccin];

    boot = {
      consoleLogLevel = 3;
      initrd.verbose = false;
      kernelParams = [
        "quiet"
        "splash"
        "udev.log_level=3"
      ];

      loader = {
        timeout = 5;
        efi.canTouchEfiVariables = true;
        limine = {
          enable = true;
          efiSupport = true;
          enableEditor = false;
          maxGenerations = 5;

          # Hand control back to the firmware's existing entry rather than
          # chainloading bootmgfw.efi. This preserves Windows' expected PCR 4
          # measurements and avoids unnecessary BitLocker recovery prompts.
          extraEntries = ''
            /Windows Boot Manager
              protocol: efi_boot_entry
              entry: Windows Boot Manager
          '';

          secureBoot = {
            enable = true;
            autoGenerateKeys = true;
            # Firmware key enrollment is intentionally manual: OEM and both
            # generations of Microsoft keys must be retained for Windows and
            # Option ROMs. See the Lilith bootstrap notes in README.md.
            autoEnrollKeys.enable = false;
          };
        };
      };

      plymouth.enable = true;
    };

    console = {
      earlySetup = true;
      font = "${pkgs.terminus_font}/share/consolefonts/ter-v32n.psf.gz";
      useXkbConfig = true;
    };

    services.xserver.xkb.layout = "at";

    catppuccin = {
      enable = true;
      autoEnable = false;
      flavor = "frappe";
      accent = "blue";
      limine.enable = true;
      plymouth.enable = true;
      tty.enable = true;
      cursors.enable = false;
    };
  };
}
