{
  flake.modules.nixos.homelab = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.homelab.qbittorrent;
    mediaShare = config.modules.homelab.mediaShare;
    downloadsRoot = mediaShare.torrentDownloadsRoot;
    completeDir = "${downloadsRoot}/complete";
    incompleteDir = "${downloadsRoot}/incomplete";
    domain = "admin.${config.services.homelab.domains.zekurio}";
    namespace = "qbittorrent";
    namespaceAddress = "10.254.0.2";
    hostAddress = "10.254.0.1";
    webuiPort = 8080;
    torrentPort = 6881;
    wireguardInterface = "mullvad-qbt";
    wireguardConfig = config.sops.secrets.mullvad_wireguard_conf.path;

    vpnSetup = pkgs.writeShellScript "qbittorrent-vpn-setup" ''
      set -euo pipefail

      # Clear an incomplete namespace left by a failed prior start.
      ${pkgs.iproute2}/bin/ip netns delete ${namespace} 2>/dev/null || true

      ${pkgs.iproute2}/bin/ip netns add ${namespace}
      ${pkgs.iproute2}/bin/ip link add qbt-host type veth peer name qbt-ns
      ${pkgs.iproute2}/bin/ip address add ${hostAddress}/30 dev qbt-host
      ${pkgs.iproute2}/bin/ip link set qbt-host up
      ${pkgs.iproute2}/bin/ip link set qbt-ns netns ${namespace}
      ${pkgs.iproute2}/bin/ip -n ${namespace} address add ${namespaceAddress}/30 dev qbt-ns
      ${pkgs.iproute2}/bin/ip -n ${namespace} link set qbt-ns up
      ${pkgs.iproute2}/bin/ip -n ${namespace} link set lo up

      # WireGuard remembers the namespace in which its UDP socket was created.
      # Moving only the interface lets its encrypted packets use Adam's normal
      # route while qBittorrent sees no non-VPN default route.
      ${pkgs.iproute2}/bin/ip link add ${wireguardInterface} type wireguard
      ${pkgs.wireguard-tools}/bin/wg setconf ${wireguardInterface} \
        <(${pkgs.wireguard-tools}/bin/wg-quick strip ${wireguardConfig})
      ${pkgs.iproute2}/bin/ip link set ${wireguardInterface} netns ${namespace}

      addresses="$(${pkgs.gnused}/bin/sed -n \
        's/^[[:space:]]*Address[[:space:]]*=[[:space:]]*//Ip' \
        ${wireguardConfig} | ${pkgs.coreutils}/bin/tr ',' ' ')"
      if [ -z "$addresses" ]; then
        echo "Mullvad config has no Interface Address" >&2
        exit 1
      fi

      has_ipv4=false
      has_ipv6=false
      for address in $addresses; do
        ${pkgs.iproute2}/bin/ip -n ${namespace} address add "$address" dev ${wireguardInterface}
        case "$address" in
          *:*) has_ipv6=true ;;
          *) has_ipv4=true ;;
        esac
      done

      mtu="$(${pkgs.gnused}/bin/sed -n \
        's/^[[:space:]]*MTU[[:space:]]*=[[:space:]]*//Ip' \
        ${wireguardConfig} | ${pkgs.coreutils}/bin/head -n1)"
      ${pkgs.iproute2}/bin/ip -n ${namespace} link set ${wireguardInterface} \
        mtu "''${mtu:-1380}" up

      $has_ipv4 && ${pkgs.iproute2}/bin/ip -n ${namespace} route add default dev ${wireguardInterface}
      $has_ipv6 && ${pkgs.iproute2}/bin/ip -n ${namespace} -6 route add default dev ${wireguardInterface}

      dns_servers="$(${pkgs.gnused}/bin/sed -n \
        's/^[[:space:]]*DNS[[:space:]]*=[[:space:]]*//Ip' \
        ${wireguardConfig} | ${pkgs.coreutils}/bin/tr ',' ' ')"
      if [ -z "$dns_servers" ]; then
        echo "Mullvad config has no Interface DNS server" >&2
        exit 1
      fi

      : > /run/qbittorrent-vpn/resolv.conf
      for server in $dns_servers; do
        printf 'nameserver %s\n' "$server" >> /run/qbittorrent-vpn/resolv.conf
      done
      chmod 0444 /run/qbittorrent-vpn/resolv.conf
    '';

    vpnTeardown = pkgs.writeShellScript "qbittorrent-vpn-teardown" ''
      ${pkgs.iproute2}/bin/ip netns delete ${namespace} 2>/dev/null || true
    '';
  in {
    options.services.homelab.qbittorrent = {
      enable = lib.mkEnableOption "qBittorrent client confined to a Mullvad WireGuard namespace";

      baseUrl = lib.mkOption {
        type = lib.types.str;
        default = "http://${namespaceAddress}:${toString webuiPort}";
        description = "URL other services on Adam use to reach the qBittorrent API.";
      };
    };

    config = lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = mediaShare.enable;
          message = "services.homelab.qbittorrent requires modules.homelab.mediaShare.";
        }
      ];

      sops.secrets.mullvad_wireguard_conf = {
        mode = "0400";
        restartUnits = ["qbittorrent-vpn.service"];
      };

      services.qbittorrent = {
        enable = true;
        inherit webuiPort;
        torrentingPort = torrentPort;
        extraArgs = ["--confirm-legal-notice"];
        serverConfig = {
          LegalNotice.Accepted = true;
          BitTorrent.Session = {
            DefaultSavePath = completeDir;
            TempPath = incompleteDir;
            TempPathEnabled = true;
            # The network namespace is the kill switch; binding qBittorrent to
            # the tunnel as well protects against accidental future routes.
            InterfaceName = wireguardInterface;
          };
          Preferences = {
            Connection.UPnP = false;
            WebUI = {
              Address = "*";
              CSRFProtection = true;
              ClickjackingProtection = true;
              HostHeaderValidation = true;
              LocalHostAuth = true;
              ServerDomains = "${domain};${namespaceAddress}";
              UPnP = false;
            };
          };
        };
      };

      systemd.services = {
        qbittorrent-vpn = {
          description = "Mullvad WireGuard namespace for qBittorrent";
          wantedBy = ["multi-user.target"];
          wants = ["network-online.target"];
          after = [
            "network-online.target"
            "sops-nix.service"
          ];
          before = ["qbittorrent.service"];
          restartTriggers = [vpnSetup];
          unitConfig.RequiresMountsFor = wireguardConfig;
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            RuntimeDirectory = "qbittorrent-vpn";
            RuntimeDirectoryMode = "0755";
            ExecStart = vpnSetup;
            ExecStop = vpnTeardown;
          };
        };

        qbittorrent = {
          bindsTo = ["qbittorrent-vpn.service"];
          after = ["qbittorrent-vpn.service"];
          unitConfig.RequiresMountsFor = downloadsRoot;
          serviceConfig = {
            NetworkNamespacePath = "/run/netns/${namespace}";
            BindReadOnlyPaths = [
              "/run/qbittorrent-vpn/resolv.conf:/etc/resolv.conf"
            ];
            SupplementaryGroups = [mediaShare.group];
            UMask = lib.mkForce mediaShare.umask;
          };
        };
      };

      # LAN/tailnet-only vhost; qBittorrent's own WebUI login is the auth
      # boundary (the temporary password is logged on first start).
      services.homelab.caddy.virtualHosts.qbittorrent = {
        inherit domain;
        extraConfig = ''
          redir /qbittorrent /qbittorrent/
          # qBittorrent cannot serve under a base path
          # (qbittorrent/qBittorrent#5693), so the proxy strips the prefix;
          # the WebUI's relative URLs keep the browser under /qbittorrent/.
          handle_path /qbittorrent/* {
            reverse_proxy ${namespaceAddress}:${toString webuiPort} {
              header_up X-Forwarded-Host {http.request.host}
            }
          }
        '';
      };
    };
  };
}
