{inputs, ...}: {
  flake.modules.nixos.adam = {
    config,
    pkgs,
    modulesPath,
    ...
  }: let
    mainUser = "zekurio";
    mainUserHome = "/home/${mainUser}";
    mainUserSshKey = "${mainUserHome}/.ssh/id_ed25519";
  in {
    imports = [
      (modulesPath + "/installer/scan/not-detected.nix")
      # Third-party modules are imported next to the options they provide.
      inputs.autoaspm.nixosModules.default
      inputs.sops-nix.nixosModules.sops
      inputs.ucodenix.nixosModules.default
    ];

    nixpkgs.hostPlatform = "x86_64-linux";

    # Boot configuration
    boot = {
      kernelParams = [
        "amd_pstate=guided"
        "microcode.amd_sha_check=off"
        "pcie_aspm=force"
        "pcie_aspm.policy=powersave"
        "consoleblank=60"
        "i915.enable_guc=3"
        "acpi_enforce_resources=lax"
      ];
      kernelModules = [
        "kvm-amd"
        "zenpower"
        "nct6687"
      ];
      extraModprobeConfig = ''
        softdep nct6687 pre: i2c_i801
        options nct6687
      '';
      extraModulePackages = [
        config.boot.kernelPackages.zenpower
        (config.boot.kernelPackages.callPackage ./_nct6687d.nix {})
      ];
      blacklistedKernelModules = [
        "k10temp"
        "nct6683"
      ];
      loader = {
        timeout = 0;
        efi.canTouchEfiVariables = true;
        systemd-boot.enable = true;
      };
      supportedFilesystems = ["zfs"];
      zfs = {
        extraPools = ["tank"];
        forceImportRoot = false;
      };
    };

    # Hardware configuration
    hardware = {
      cpu.amd = {
        updateMicrocode = true;
        ryzen-smu.enable = true;
      };
      graphics = {
        enable = true;
        extraPackages = with pkgs; [
          intel-media-driver
          intel-compute-runtime
          vpl-gpu-rt
          nvtopPackages.intel
        ];
      };
    };

    environment.sessionVariables = {
      LIBVA_DRIVER_NAME = "iHD";
    };

    powerManagement.cpuFreqGovernor = "schedutil";

    services.ucodenix.enable = true;

    # sshd itself (hardened defaults + URL-sourced keys) comes from modules.ssh.
    services.openssh.settings.AllowAgentForwarding = true;

    home-manager.users.${mainUser} = {
      # Enable truecolor output for terminal applications.
      home.sessionVariables.COLORTERM = "truecolor";

      programs.keychain = {
        enable = true;
        enableFishIntegration = true;
        keys = [mainUserSshKey];
      };

      programs.ssh = {
        enable = true;
        enableDefaultConfig = false;
        settings."github.com" = {
          IdentityFile = mainUserSshKey;
          IdentitiesOnly = true;
          AddKeysToAgent = "yes";
        };
      };

      programs.git.settings.user = {
        signingkey = mainUserSshKey;
      };
    };

    modules.virtualization.enable = true;

    modules.homelab.mediaShare = {
      enable = true;
      collaborators = [mainUser];
      nfs.enable = true;
      samba = {
        enable = true;
        interfaces = [
          "enp42s0"
          "tailscale0"
        ];
        discovery = {
          enable = true;
          interfaces = ["enp42s0"];
        };
        passwordFiles.zekurio = config.sops.secrets.smb_password_zekurio.path;
      };
      userShares = {
        ${mainUser} = {
          quota = "50G";
        };
      };
    };

    # Networking configuration
    networking = {
      hostName = "adam";
      useDHCP = false;
      networkmanager.enable = false;
      firewall.enable = true;
      hostId = "eab7e93e";
      hosts = {
        # The auth name must resolve to adam's LAN address, not loopback:
        # systemd-resolved hands /etc/hosts entries to containers, where
        # 127.0.0.1 is the container itself, and Fluxer's SSO validation
        # rejects loopback issuers outright.
        "10.0.0.2" = ["auth.${config.services.homelab.domains.zekurio}"];
      };
      useNetworkd = true;
    };

    services.resolved = {
      enable = true;
      settings.Resolve = {
        DNS = ["10.0.0.1"];
        DNSSEC = false;
        Domains = ["~."];
        FallbackDNS = [];
        DNSStubListener = true;
      };
    };

    systemd.network = {
      enable = true;
      networks."10-lan" = {
        matchConfig.Name = "enp42s0";
        networkConfig = {
          DHCP = "yes";
          DNS = "10.0.0.1";
        };
        dhcpV4Config = {
          UseDNS = false;
          UseNTP = true;
        };
      };
      networks."99-podman" = {
        matchConfig.Name = "podman0 fluxer0 veth*";
        networkConfig.DHCP = "no";
        linkConfig.Unmanaged = true;
      };
    };

    # SOPS secrets configuration. The age key is hand-placed during bootstrap
    # (see README) and deliberately not generated on the host.
    sops = {
      # The activation script's unit restart list is deprecated in NixOS 26.11.
      useSystemdActivation = true;
      # sops-nix master builds sops-install-secrets with buildGo125Module,
      # which nixpkgs removed on 2026-09-15 (Go 1.25 EOL) as a throwing alias.
      # Call sops-nix's package expression with that builder shimmed to the
      # current one so its own vendorHash stays in charge. Drop this when
      # upstream bumps the builder.
      package =
        (pkgs.callPackage "${inputs.sops-nix}" {
          pkgs = pkgs.extend (_: prev: {buildGo125Module = prev.buildGo126Module;});
        }).sops-install-secrets;
      defaultSopsFile = ../../../secrets/adam.yaml;
      age = {
        keyFile = "/var/lib/sops-nix/key.txt";
        generateKey = false;
        sshKeyPaths = [];
      };
      gnupg.sshKeyPaths = [];
      secrets.tailscale_auth_key = {};
      secrets.smb_password_zekurio = {};
    };

    # System packages
    environment.systemPackages = with pkgs; [
      kitty.terminfo
      ryzen-monitor-ng
      zfs
      lm_sensors
      intel-gpu-tools
      lsof
    ];

    services.autoaspm.enable = true;

    services.homelab = {
      alloy.enable = true;
      blitzcrank.enable = true;
      configarr.enable = true;
      beets.enable = true;
      copyparty.enable = true;
      coolercontrol.enable = true;
      dashthing.enable = true;
      fluxer.enable = true;
      immich.enable = true;
      jellyfin.enable = true;
      inviterr.enable = true;
      lidarr.enable = true;
      mediaCleanup.enable = true;
      navidrome.enable = true;
      pocket-id.enable = true;
      prowlarr.enable = true;
      radarr.enable = true;
      sabnzbd.enable = true;
      seerr.enable = true;
      slskd.enable = true;
      sonarr.enable = true;
      t3code.enable = true;
      valheim = {
        enable = true;
        serverName = "Die geilsten Gamer e.V. (nicht offiziell)";
        public = true;
        extraEnvironment = {
          SERVER_ARGS = "-modifier combat hard";
          VPCFG_Game_enabled = "false";

          # V+ modifiers are percentage changes: +100 doubles, -100 removes.
          VPCFG_Gathering_enabled = "true";
          VPCFG_Gathering_copperOre = "100";
          VPCFG_Gathering_tinOre = "100";
          VPCFG_Gathering_ironScrap = "100";
          VPCFG_Gathering_silverOre = "100";
          VPCFG_Gathering_copperScrap = "100";
          VPCFG_Gathering_flametalOre = "100";

          VPCFG_Pickable_enabled = "true";
          VPCFG_Pickable_edibles = "100";
          VPCFG_Pickable_flowersAndIngredients = "100";

          VPCFG_Beehive_enabled = "true";
          # Seconds per honey: 600 gives 2x production; capacity scales with it.
          VPCFG_Beehive_honeyProductionSpeed = "600";
          VPCFG_Beehive_maximumHoneyPerBeehive = "8";

          VPCFG_Items_enabled = "true";
          VPCFG_Items_itemStackMultiplier = "700";
          VPCFG_Items_noTeleportPrevention = "true";

          # The global loot multiplier also multiplies trophies and boss rewards.
          VPCFG_LootDrop_enabled = "true";
          VPCFG_LootDrop_lootDropAmountMultiplier = "100";

          VPCFG_Inventory_enabled = "true";
          VPCFG_Inventory_woodChestRows = "4";
          VPCFG_Inventory_personalChestRows = "4";
          VPCFG_Inventory_ironChestRows = "8";
          VPCFG_Inventory_blackmetalChestRows = "8";

          VPCFG_CraftFromChest_enabled = "true";
          VPCFG_CraftFromChest_checkFromWorkbench = "true";
          VPCFG_CraftFromChest_range = "40";

          VPCFG_Workbench_enabled = "true";
          VPCFG_Workbench_workbenchRange = "100";
          # Otherwise spawn suppression inherits the expanded build radius.
          VPCFG_Workbench_workbenchEnemySpawnRange = "20";

          VPCFG_Kiln_enabled = "true";
          # productionSpeed is seconds per item: 7.5/15 seconds doubles throughput.
          VPCFG_Kiln_productionSpeed = "7.5";
          VPCFG_Kiln_autoFuel = "true";
          VPCFG_Kiln_autoDeposit = "true";
          VPCFG_Kiln_autoRange = "10";
          VPCFG_Kiln_dontProcessFineWood = "true";
          VPCFG_Kiln_dontProcessRoundLog = "true";
          VPCFG_Kiln_stopAutoFuelThreshold = "200";

          VPCFG_Smelter_enabled = "true";
          VPCFG_Smelter_productionSpeed = "15";
          VPCFG_Smelter_autoFuel = "true";
          VPCFG_Smelter_autoDeposit = "true";
          VPCFG_Smelter_autoRange = "10";

          VPCFG_Furnace_enabled = "true";
          VPCFG_Furnace_productionSpeed = "15";
          VPCFG_Furnace_autoFuel = "true";
          VPCFG_Furnace_autoDeposit = "true";
          VPCFG_Furnace_autoRange = "10";

          VPCFG_Player_enabled = "true";
          VPCFG_Player_baseMaximumWeight = "600";
          VPCFG_Player_deathPenaltyMultiplier = "-100";
          VPCFG_Player_autoRepair = "true";
          VPCFG_Player_cropNotifier = "true";
          VPCFG_Player_reequipItemsAfterSwimming = "true";

          VPCFG_Map_enabled = "true";
          VPCFG_Map_shareMapProgression = "true";
          VPCFG_Map_displayCartsAndBoats = "true";

          VPCFG_FireSource_enabled = "true";
          VPCFG_FireSource_torches = "true";
        };
      };
      windrose = {
        enable = false;
        maxPlayers = 4;
        hostNetwork = true;
        p2pProxyAddress = "10.0.0.2";
      };
    };

    system.autoUpgrade = {
      enable = true;
      flake = "github:zekurio/nix/main#adam";
      dates = "Sun *-*-* 03:00:00";
      randomizedDelaySec = "45min";
    };

    # DO NOT TOUCH THIS
    system.stateVersion = "25.05";
  };
}
