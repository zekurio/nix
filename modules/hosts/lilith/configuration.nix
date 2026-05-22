{
  config,
  inputs,
  lib,
  pkgs,
  modulesPath,
  ...
}: let
  mainUser = "zekurio";
  nyx = inputs.chaotic-nyx.packages.${pkgs.stdenv.hostPlatform.system};
  cachyKernel = nyx.linux_cachyos-lto;
in {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ../../nixos/users/zekurio.nix
    ./disko.nix
  ];

  networking.hostName = "lilith";

  boot.kernelPackages = pkgs.linuxPackagesFor cachyKernel;
  boot.kernelParams = [
    "amd_pstate=guided"
    "acpi_enforce_resources=lax"
  ];
  boot.kernelModules = [
    "kvm-amd"
    "it87"
  ];
  boot.extraModprobeConfig = ''
    options it87 force_id=0x8628
  '';
  boot.initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "ahci"
    "usbhid"
    "sd_mod"
    "amdgpu"
  ];

  hardware.cpu.amd.updateMicrocode = true;
  hardware.enableRedistributableFirmware = true;
  hardware.firmware = [pkgs.linux-firmware];

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  hardware.amdgpu = {
    opencl.enable = true;
    initrd.enable = true;
  };

  # Force RADV over AMDVLK
  environment.variables.AMD_VULKAN_ICD = "RADV";

  # LACT daemon for overclocking/fan control
  services.lact.enable = true;
  environment.systemPackages = with pkgs; [
    rocmPackages.rocm-smi
  ];

  boot.loader = {
    efi.canTouchEfiVariables = true;
    grub.enable = false;
    systemd-boot.enable = false;
    limine = {
      enable = true;
      efiSupport = true;
    };
  };

  powerManagement.cpuFreqGovernor = "schedutil";

  services.openssh.enable = true;

  # 1Password — allow helium browser
  environment.etc."1password/custom_allowed_browsers".text = "helium\n";

  # Helium browser — managed chromium policy
  environment.etc."chromium/policies/managed/policies.json".text = builtins.toJSON {
    ExtensionInstallBlocklist = ["*"];
    ExtensionInstallAllowlist = [
      "blockjmkbacgjkknlgpkjjiijinjdanf" # uBlock Origin
      "mnjggcdmjocbbbhaepdhchncahnbgone" # SponsorBlock
      "jinjaccalgkegednnccohejagnlnfdag" # Violentmonkey
      "aeblfdkhhhdcdjpifhhbdiojplfjncoa" # 1Password
    ];
    ExtensionInstallForcelist = [
      "blockjmkbacgjkknlgpkjjiijinjdanf"
      "mnjggcdmjocbbbhaepdhchncahnbgone"
      "jinjaccalgkegednnccohejagnlnfdag"
      "aeblfdkhhhdcdjpifhhbdiojplfjncoa"
    ];
    ExtensionInstallSources = ["https://services.helium.imput.net/*"];
    DefaultSearchProviderEnabled = true;
    DefaultSearchProviderName = "Kagi";
    DefaultSearchProviderSearchURL = "https://kagi.com/search?q={searchTerms}";
    DefaultSearchProviderSuggestURL = "https://kagi.com/api/autosuggest?q={searchTerms}";
    SearchSuggestEnabled = true;
    RestoreOnStartup = 1;
    DefaultBrowserSettingEnabled = false;
    DeveloperToolsAvailability = 1;
  };

  # Steam
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
  };

  programs.dank-material-shell = {
    greeter = {
      enable = true;
      compositor.name = "niri";
    };
  };

  programs.dsearch.enable = true;

  programs.niri.enable = true;

  nix.settings.trusted-users = [mainUser];

  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
    nerd-fonts.jetbrains-mono
  ];

  networking.networkmanager.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  services.resolved.enable = true;

  time.timeZone = "Europe/Vienna";

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    extraSpecialArgs = {inherit inputs;};

    users.${mainUser} = {
      imports = [
        ../../home/zekurio
        ../../home/zekurio/helium.nix
        ../../home/zekurio/lilith-desktop.nix
      ];
    };
  };

  system.stateVersion = "26.05";
}
