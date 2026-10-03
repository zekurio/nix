{
  flake.modules.nixos.lilith = {pkgs, ...}: {
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
          # The menu and Linux handoff use separate GOP resolution settings.
          resolution = "2560x1440";

          style = {
            wallpapers = [];
            backdrop = "191919";
            interface = {
              resolution = "2560x1440";
              branding = "LILITH";
              brandingColor = "F44336";
              helpColor = "BDBDBD";
              helpColorBright = "F44336";
            };
            graphicalTerminal = {
              font = {
                scale = "2x2";
                spacing = 1;
              };
              foreground = "EEEEEE";
              background = "00262626";
              brightForeground = "FFFFFF";
              brightBackground = "333333";
              palette = "191919;F44336;81C784;FFB74D;90CAF9;CE93D8;BDBDBD;EEEEEE";
              brightPalette = "333333;EF5350;A5D6A7;FFCC80;BBDEFB;E1BEE7;EEEEEE;FFFFFF";
              margin = 64;
              marginGradient = 0;
            };
          };

          # Hand control back to the firmware's existing entry rather than
          # chainloading bootmgfw.efi. This preserves Windows' expected PCR 4
          # measurements and avoids unnecessary BitLocker recovery prompts.
          extraEntries = ''
            /Windows Boot Manager
              protocol: efi_boot_entry
              entry: Windows Boot Manager
              comment: Restart into Windows via UEFI firmware
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
  };
}
