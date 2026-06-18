{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}: let
  mainUser = "zekurio";
in {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ./disko.nix
  ];

  boot = {
    initrd = {
      availableKernelModules = [
        "nvme"
        "xhci_pci"
        "usb_storage"
        "sd_mod"
        "rtsx_pci_sdmmc"
      ];
      systemd = {
        enable = true;
        tpm2.enable = true;
      };
    };
    kernelModules = ["kvm-amd"];
    kernelParams = [
      "amd_pstate=active"
      "mem_sleep_default=deep"
    ];
    loader = {
      timeout = 5;
      efi.canTouchEfiVariables = true;
      systemd-boot.enable = lib.mkForce false;
      limine = {
        enable = true;
        efiSupport = true;
        secureBoot.enable = true;
      };
    };
    plymouth.enable = true;
  };

  hardware = {
    cpu.amd.updateMicrocode = true;
    graphics = {
      enable = true;
      enable32Bit = true;
    };
    bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
    nvidia = {
      open = true;
      nvidiaSettings = true;
      powerManagement = {
        enable = true;
        finegrained = true;
      };
      prime.offload = {
        enable = true;
        enableOffloadCmd = true;
      };
    };
  };

  powerManagement = {
    enable = true;
    cpuFreqGovernor = "schedutil";
  };

  services = {
    xserver = {
      enable = true;
      videoDrivers = [
        "amdgpu"
        "nvidia"
      ];
    };
    desktopManager.plasma6.enable = true;
    displayManager.plasma-login-manager.enable = true;
    pipewire = {
      enable = true;
      alsa = {
        enable = true;
        support32Bit = true;
      };
      jack.enable = true;
      pulse.enable = true;
    };
    power-profiles-daemon.enable = true;
    fstrim.enable = true;
    fwupd.enable = true;
    printing.enable = true;
    openssh = {
      enable = true;
      settings = {
        AllowAgentForwarding = true;
        PasswordAuthentication = false;
        PermitRootLogin = "no";
      };
    };
    logind.settings.Login = {
      HandleLidSwitch = "suspend-then-hibernate";
      HandleLidSwitchExternalPower = "suspend";
      HandleLidSwitchDocked = "ignore";
      HandlePowerKey = "suspend";
    };
  };

  systemd.sleep.settings.Sleep = {
    AllowSuspend = "yes";
    AllowHibernation = "yes";
    AllowSuspendThenHibernate = "yes";
    AllowHybridSleep = "yes";
    HibernateDelaySec = "2h";
  };

  security = {
    polkit.enable = true;
    rtkit.enable = true;
    tpm2 = {
      enable = true;
      tctiEnvironment.enable = true;
    };
  };

  networking = {
    hostName = "sachiel";
    networkmanager.enable = true;
    firewall.enable = true;
  };

  programs = {
    dconf.enable = true;
    _1password.enable = true;
    _1password-gui = {
      enable = true;
      polkitPolicyOwners = [mainUser];
    };
  };

  environment = {
    etc."1password/custom_allowed_browsers".text = ''
      helium
    '';
    sessionVariables = {
      NIXOS_OZONE_WL = "1";
    };
    systemPackages = with pkgs; [
      klassy
      sbctl
      tpm2-tools
      pciutils
      usbutils
      lm_sensors
      nvtopPackages.nvidia
      powertop
      wl-clipboard
    ];
  };

  fonts = {
    packages = with pkgs; [
      fira-sans
      nerd-fonts.fira-code
      noto-fonts-color-emoji
      roboto-slab
    ];
    fontconfig.defaultFonts = {
      sansSerif = ["Fira Sans"];
      monospace = ["FiraCode Nerd Font"];
      serif = ["Roboto Slab"];
      emoji = ["Noto Color Emoji"];
    };
  };

  users.users.${mainUser}.extraGroups = [
    "audio"
    "networkmanager"
    "tss"
  ];

  home-manager.users.${mainUser}.imports = [
    ./home.nix
  ];

  catppuccin = {
    flavor = "frappe";
    accent = "blue";
    limine.enable = true;
    plymouth.enable = true;
    tty.enable = true;
    cursors = {
      enable = true;
      flavor = "frappe";
      accent = "blue";
    };
  };

  system.stateVersion = "25.05";
}
