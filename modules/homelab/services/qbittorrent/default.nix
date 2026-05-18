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
  resolvConfPath = "${runtimeDir}/resolv.conf";
  hostAddress = "10.200.0.1";
  qbitAddress = "10.200.0.2";
  prefixLength = "30";
  lanInterface = "enp42s0";

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
    ${pkgs.iproute2}/bin/ip netns exec ${lib.escapeShellArg netns} \
      ${pkgs.iproute2}/bin/ip route replace default via ${hostAddress} dev qbit-veth
  '';

  teardownNetns = pkgs.writeShellScript "qbittorrent-netns-down" ''
    set -euo pipefail

    ${pkgs.iproute2}/bin/ip link delete qbit-host >/dev/null 2>&1 || true
    ${pkgs.iproute2}/bin/ip netns delete ${lib.escapeShellArg netns} >/dev/null 2>&1 || true
  '';

  prepareWgConfig = pkgs.writeShellScript "qbittorrent-mullvad-prepare-config" ''
    set -euo pipefail

    install -m 0600 ${lib.escapeShellArg config.sops.secrets.qbittorrent_mullvad_wg_conf.path} ${lib.escapeShellArg wgConfigPath}
    dns_servers="$(
      ${pkgs.gawk}/bin/awk -F '=' '
        /^[[:space:]]*DNS[[:space:]]*=/ {
          gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2)
          gsub(/,/, " ", $2)
          print $2
        }
      ' ${lib.escapeShellArg wgConfigPath}
    )"

    ${pkgs.gawk}/bin/awk -F '=' '
      /^[[:space:]]*DNS[[:space:]]*=/ { next }
      { print }
    ' ${lib.escapeShellArg wgConfigPath} > ${lib.escapeShellArg wgConfigPath}.tmp
    mv ${lib.escapeShellArg wgConfigPath}.tmp ${lib.escapeShellArg wgConfigPath}
    chmod 0600 ${lib.escapeShellArg wgConfigPath}

    : > ${lib.escapeShellArg resolvConfPath}
    for dns in $dns_servers; do
      printf 'nameserver %s\n' "$dns" >> ${lib.escapeShellArg resolvConfPath}
    done
    if [ ! -s ${lib.escapeShellArg resolvConfPath} ]; then
      printf 'nameserver 10.64.0.1\n' > ${lib.escapeShellArg resolvConfPath}
    fi
    chmod 0644 ${lib.escapeShellArg resolvConfPath}
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
        gawk
        iproute2
        wireguard-tools
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        RuntimeDirectory = "qbittorrent-mullvad";
        RuntimeDirectoryMode = "0700";
        ExecStartPre = prepareWgConfig;
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
        BindReadOnlyPaths = ["${resolvConfPath}:/etc/resolv.conf"];
        SupplementaryGroups = ["share"];
        UMask = lib.mkForce shareUmask;
      };
    };

    networking.nat = {
      enable = true;
      externalInterface = lanInterface;
      internalInterfaces = ["qbit-host"];
    };

    services.homelab.caddy.virtualHosts."qbittorrent" = {
      inherit domain;
      forwardAuth = "127.0.0.1:4180";
      reverseProxy = "${qbitAddress}:${toString webuiPort}";
    };
  };
}
