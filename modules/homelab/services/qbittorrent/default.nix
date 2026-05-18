{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.homelab.qbittorrent;

  domain = "qbit.schnitzelflix.xyz";
  webuiPort = 8080;
  torrentingPort = 51013;
  shareUmask = "0002";
  torrentDownloadsDir = "/tank/media/torrents";

  netns = "qbit";
  wgInterface = "wg0";
  runtimeDir = "/run/qbittorrent-mullvad";
  wgConfigPath = "${runtimeDir}/${wgInterface}.conf";
  hostAddress = "10.200.0.1";
  qbitAddress = "10.200.0.2";
  prefixLength = "30";

  setupNetns = pkgs.writeShellScript "qbittorrent-netns-up" ''
    set -euo pipefail

    ${pkgs.iproute2}/bin/ip netns list | ${pkgs.gnugrep}/bin/grep -qw ${lib.escapeShellArg netns} \
      || ${pkgs.iproute2}/bin/ip netns add ${lib.escapeShellArg netns}

    if ! ${pkgs.iproute2}/bin/ip link show qbit-host >/dev/null 2>&1; then
      ${pkgs.iproute2}/bin/ip link add qbit-host type veth peer name qbit-veth
      ${pkgs.iproute2}/bin/ip link set qbit-veth netns ${lib.escapeShellArg netns}
    fi

    ${pkgs.iproute2}/bin/ip addr replace ${hostAddress}/${prefixLength} dev qbit-host
    ${pkgs.iproute2}/bin/ip link set qbit-host up

    ${pkgs.iproute2}/bin/ip netns exec ${lib.escapeShellArg netns} \
      ${pkgs.iproute2}/bin/ip addr replace ${qbitAddress}/${prefixLength} dev qbit-veth
    ${pkgs.iproute2}/bin/ip netns exec ${lib.escapeShellArg netns} \
      ${pkgs.iproute2}/bin/ip link set qbit-veth up
    ${pkgs.iproute2}/bin/ip netns exec ${lib.escapeShellArg netns} \
      ${pkgs.iproute2}/bin/ip link set lo up
  '';

  teardownNetns = pkgs.writeShellScript "qbittorrent-netns-down" ''
    set -euo pipefail

    ${pkgs.iproute2}/bin/ip link delete qbit-host >/dev/null 2>&1 || true
    ${pkgs.iproute2}/bin/ip netns delete ${lib.escapeShellArg netns} >/dev/null 2>&1 || true
  '';
in {
  options.services.homelab.qbittorrent = {
    enable = lib.mkEnableOption "qBittorrent behind Mullvad WireGuard and Caddy forward auth";
  };

  config = lib.mkIf cfg.enable {
    sops.secrets.qbittorrent_mullvad_wg_conf = {
      owner = "root";
      group = "root";
      mode = "0400";
    };

    systemd.tmpfiles.rules = [
      "d ${runtimeDir} 0700 root root -"
    ];

    systemd.services.qbittorrent-netns = {
      description = "qBittorrent network namespace";
      wantedBy = ["multi-user.target"];
      before = [
        "qbittorrent-mullvad.service"
        "qbittorrent.service"
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = setupNetns;
        ExecStop = teardownNetns;
      };
    };

    systemd.services.qbittorrent-mullvad = {
      description = "Mullvad WireGuard tunnel for qBittorrent";
      wantedBy = ["multi-user.target"];
      requires = ["qbittorrent-netns.service"];
      after = ["qbittorrent-netns.service"];
      before = ["qbittorrent.service"];
      path = with pkgs; [
        bash
        iproute2
        wireguard-tools
        openresolv
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        RuntimeDirectory = "qbittorrent-mullvad";
        RuntimeDirectoryMode = "0700";
        ExecStartPre = "${pkgs.coreutils}/bin/ln -sf ${config.sops.secrets.qbittorrent_mullvad_wg_conf.path} ${wgConfigPath}";
        ExecStart = "${pkgs.iproute2}/bin/ip netns exec ${netns} ${pkgs.wireguard-tools}/bin/wg-quick up ${wgConfigPath}";
        ExecStop = "${pkgs.iproute2}/bin/ip netns exec ${netns} ${pkgs.wireguard-tools}/bin/wg-quick down ${wgConfigPath}";
      };
    };

    services.qbittorrent = {
      enable = true;
      user = "share";
      group = "share";
      inherit webuiPort torrentingPort;
      openFirewall = false;
      serverConfig = {
        LegalNotice.Accepted = true;
        BitTorrent.Session.DefaultSavePath = "${torrentDownloadsDir}/manual";
        Preferences = {
          Connection = {
            Interface = wgInterface;
            PortRangeMin = torrentingPort;
          };
          Downloads = {
            SavePath = "${torrentDownloadsDir}/manual";
            TempPath = "${torrentDownloadsDir}/incomplete";
            TempPathEnabled = true;
          };
          WebUI = {
            Address = qbitAddress;
            AuthSubnetWhitelist = hostAddress;
            AuthSubnetWhitelistEnabled = true;
          };
        };
      };
    };

    systemd.services.qbittorrent = {
      requires = ["qbittorrent-mullvad.service"];
      after = ["qbittorrent-mullvad.service"];
      serviceConfig = {
        NetworkNamespacePath = "/run/netns/${netns}";
        SupplementaryGroups = ["share"];
        UMask = lib.mkForce shareUmask;
      };
    };

    services.homelab.caddy.virtualHosts."qbittorrent" = {
      inherit domain;
      forwardAuth = "127.0.0.1:4180";
      reverseProxy = "${qbitAddress}:${toString webuiPort}";
    };
  };
}
