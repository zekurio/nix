{
  inputs,
  lib,
  pkgs,
  ...
}: let
  mainUser = "zekurio";
in {
  imports = [
    inputs.nixos-hardware.nixosModules.asus-zephyrus-ga401iv
    ../../nixos/users/zekurio.nix
  ];

  networking.hostName = "sachiel";

  hardware.enableRedistributableFirmware = true;
  hardware.firmware = [pkgs.linux-firmware];

  boot.loader = {
    efi.canTouchEfiVariables = true;
    systemd-boot.enable = true;
  };

  # Hibernation resumes from the encrypted swap LV defined in ./disko.nix.
  powerManagement.enable = true;
  systemd.sleep.extraConfig = ''
    HibernateMode=platform shutdown
    HibernateState=disk
  '';

  # nixos-hardware handles PRIME offload, modesetting, dynamic boost
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # Force RADV over AMDVLK
  environment.variables.AMD_VULKAN_ICD = "RADV";

  services.displayManager.plasma-login-manager.enable = true;
  services.desktopManager.plasma6.enable = true;

  services.openssh.enable = true;
  services.resolved.enable = true;

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

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  networking.networkmanager.enable = true;

  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
    nerd-fonts.jetbrains-mono
  ];

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
        ../../home/zekurio/sachiel-desktop.nix
      ];
    };
  };

  system.stateVersion = "26.05";
}
