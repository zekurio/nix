{pkgs, ...}: {
  boot = {
    consoleLogLevel = 3;
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

        # Monochrome, from shadcn/ui's default dark neutrals: the terminal is
        # a card (171717) on the background (0a0a0a), with muted text for
        # help. The palette hues are greys too, so nothing in the menu is
        # coloured.
        style = {
          wallpapers = [];
          backdrop = "0A0A0A";
          interface = {
            resolution = "2560x1440";
            branding = "LILITH";
            brandingColor = "FAFAFA";
            helpColor = "A1A1A1";
            helpColorBright = "FAFAFA";
          };
          graphicalTerminal = {
            font = {
              scale = "2x2";
              spacing = 1;
            };
            foreground = "E5E5E5";
            background = "00171717";
            brightForeground = "FAFAFA";
            brightBackground = "262626";
            palette = "171717;A3A3A3;A3A3A3;A3A3A3;A3A3A3;A3A3A3;A3A3A3;D4D4D4";
            brightPalette = "404040;E5E5E5;E5E5E5;E5E5E5;E5E5E5;E5E5E5;E5E5E5;FAFAFA";
            margin = 64;
            marginGradient = 0;
          };
        };

        # Windows keeps its own ESP on the Intenso drive. Rebooting into the
        # firmware entry by name avoids pinning that ESP's partition GUID,
        # which changes with every Windows reinstall.
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
}
