{
  config,
  lib,
  pkgs,
  ...
}: let
  upstream = pkgs.aurral;
in {
  # nixos-unstable still ships Aurral 2.13.0, a Lidarr companion whose
  # metadata search broke when BrainzMash's public relay stopped answering.
  # 3.0 runs the Library and serves Subsonic itself, and 3.0.1 moves to a
  # working metadata server. This file carries nixpkgs master's 3.0.1
  # package and its module's ExecStart until the channel catches up.
  config = lib.mkIf config.services.homelab.aurral.enable {
    services.aurral.package =
      lib.warnIf (upstream.version != "2.13.0")
      "nixpkgs now ships Aurral ${upstream.version}; delete modules/homelab/services/aurral/backport.nix."
      (upstream.overrideAttrs (finalAttrs: old: {
        version = "3.0.1";
        src = pkgs.fetchFromGitHub {
          owner = "lklynet";
          repo = "aurral";
          tag = "v${finalAttrs.version}";
          hash = "sha256-4F/bwmTYB1qC68VPiXh3tjLQdNNVwftpy05i7B8poTE=";
        };
        # fetchPnpmDeps takes src from finalAttrs, so only the hash changes.
        pnpmDeps = old.pnpmDeps.overrideAttrs {
          outputHash = "sha256-o9BTUedHn9nuUPWaXTKSKa/pvEB7Pq2Fw8ehgi6h0RU=";
        };
        nativeCheckInputs = old.nativeCheckInputs ++ [pkgs.patchelf];
        # The Hub tests start Cloudflare's prebuilt workerd for a local D1
        # database, and reach it over TLS.
        preCheck = ''
          patchelf --set-interpreter ${pkgs.stdenv.cc.bintools.dynamicLinker} \
            --set-rpath ${lib.makeLibraryPath [pkgs.stdenv.cc.libc]} \
            node_modules/.pnpm/@cloudflare+workerd-linux-*/node_modules/@cloudflare/workerd-linux-*/bin/workerd
          export SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
        '';
      }));

    # PrivatePIDs makes Aurral PID 1 of its namespace, and 3.0 forks plugin
    # and download processes that nothing else would reap.
    systemd.services.aurral.serviceConfig.ExecStart = lib.mkForce "${lib.getExe pkgs.catatonit} -- ${lib.getExe config.services.aurral.package}";
  };
}
