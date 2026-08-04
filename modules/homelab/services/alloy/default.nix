{
  flake.modules.nixos.homelab = {
    config,
    inputs,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.homelab.alloy;
    domain = "clips.${config.services.homelab.domains.zekurio}";
    port = 2552;
    storageDirs = {
      clips = "/tank/alloy/clips";
      thumbnails = "/var/lib/alloy/assets/thumbnails";
      assets = "/var/lib/alloy/assets/users";
    };
    upstreamPackage = inputs.alloy.packages.${pkgs.stdenv.hostPlatform.system}.alloy;
    zodSource = pkgs.applyPatches {
      name = "alloy-1.0.1-zod-source";
      src = upstreamPackage.src;
      patches = [
        (pkgs.fetchpatch {
          # The v1.0.1 TypeBox refactor crashes while parsing default config
          # and string-valued environment variables. Revert it until fixed.
          url = "https://github.com/zekurio/alloy/commit/14675809fe5562730f7a009a9720e23c494c428c.patch";
          hash = "sha256-kdyidnp22YzF+mKWo94tBx43Omb/7spaAbeAVSxHDNo=";
          revert = true;
          excludes = ["nix/package.nix"];
        })
      ];
    };
    alloyPackage = upstreamPackage.override {
      source = zodSource;
      pnpmDepsHash = "sha256-Ct4PiLUKiyui1bqfDmA7vJGmpMuD08zIcNb2RcE0ZCA=";
    };
  in {
    imports = [
      inputs.alloy.nixosModules.default
    ];

    options.services.homelab.alloy = {
      enable = lib.mkEnableOption "Alloy self-hosted clip server";
    };

    config = lib.mkIf cfg.enable {
      services.alloy-server = {
        enable = true;
        inherit port;
        publicServerUrl = "https://${domain}";
        package = alloyPackage;
        ffmpegPackage = pkgs.jellyfin-ffmpeg;
        extraGroups = [
          "render"
          "video"
        ];
        environment = {
          ALLOY_FFMPEG_PATH = "${pkgs.jellyfin-ffmpeg}/bin/ffmpeg";
          LIBVA_DRIVER_NAME = "iHD";
        };
        environmentFile = config.sops.secrets.alloy_env.path;

        storage.fs = {
          clipsPath = storageDirs.clips;
          thumbnailsPath = storageDirs.thumbnails;
          assetsPath = storageDirs.assets;
        };

        limits.defaultStorageQuotaBytes = 16106127360;
      };

      systemd.tmpfiles.rules = let
        user = config.services.alloy-server.user;
        group = config.services.alloy-server.group;
      in [
        "d /tank/alloy 0750 ${user} ${group} - -"
        "d ${storageDirs.clips} 0750 ${user} ${group} - -"
        "d /var/lib/alloy/assets 0750 ${user} ${group} - -"
        "d ${storageDirs.thumbnails} 0750 ${user} ${group} - -"
        "d ${storageDirs.assets} 0750 ${user} ${group} - -"
      ];

      systemd.services.alloy-storage-dirs = let
        user = config.services.alloy-server.user;
        group = config.services.alloy-server.group;
        dirs = [
          "/tank/alloy"
          storageDirs.clips
          "/var/lib/alloy/assets"
          storageDirs.thumbnails
          storageDirs.assets
        ];
      in {
        description = "Create Alloy storage directories";
        requires = ["tank-datasets.service"];
        after = ["tank-datasets.service"];
        before = ["alloy-server.service"];
        path = [pkgs.coreutils];
        serviceConfig.Type = "oneshot";
        script = ''
          install -d -m 0750 -o ${lib.escapeShellArg user} -g ${lib.escapeShellArg group} ${lib.escapeShellArgs dirs}
        '';
      };

      systemd.services.alloy-server = {
        requires = ["alloy-storage-dirs.service"];
        after = ["alloy-storage-dirs.service"];
        serviceConfig = {
          PrivateDevices = lib.mkForce false;
          DeviceAllow = ["/dev/dri/renderD128"];
        };
      };

      sops.secrets.alloy_env = {
        owner = config.services.alloy-server.user;
        group = config.services.alloy-server.group;
        mode = "0400";
      };

      services.homelab.caddy.virtualHosts."alloy" = {
        inherit domain;
        reverseProxy = "127.0.0.1:${toString port}";
      };

      services.homelab.newt.resources.alloy = {
        displayName = "Alloy";
        inherit domain;
        target = "127.0.0.1:${toString port}";
      };
    };
  };
}
