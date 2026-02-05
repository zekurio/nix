{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.modules.wireguard-netns;
  nsName = cfg.namespace;
  nsPath = "/var/run/netns/${nsName}";

  # Script to parse Mullvad wg-quick config, set up namespace + WireGuard
  wgUp = pkgs.writeShellScript "wg-netns-up" ''
    set -e

    WG_CONF="${config.sops.secrets.wg_config.path}"

    # Parse Address (first IPv4 only, strip CIDR friends after comma)
    WG_ADDRESS=$(${pkgs.gawk}/bin/awk -F' *= *' '/^Address/ {split($2, a, ","); print a[1]}' "$WG_CONF")

    # Parse DNS (first entry)
    WG_DNS=$(${pkgs.gawk}/bin/awk -F' *= *' '/^DNS/ {split($2, a, ","); gsub(/ /, "", a[1]); print a[1]}' "$WG_CONF")

    # Generate wg-setconf compatible config (strip Address/DNS lines)
    WG_STRIPPED=$(${pkgs.gnused}/bin/sed '/^Address/d;/^DNS/d' "$WG_CONF")

    # Create network namespace
    ${pkgs.iproute2}/bin/ip netns add ${nsName} 2>/dev/null || true

    # Bring up loopback inside namespace
    ${pkgs.iproute2}/bin/ip -n ${nsName} link set lo up

    # Create WireGuard interface in host namespace
    ${pkgs.iproute2}/bin/ip link add wg0 type wireguard

    # Move it into the VPN namespace
    ${pkgs.iproute2}/bin/ip link set wg0 netns ${nsName}

    # Apply WireGuard config from stripped config
    TMPCONF=$(mktemp)
    echo "$WG_STRIPPED" > "$TMPCONF"
    ${pkgs.iproute2}/bin/ip netns exec ${nsName} \
      ${pkgs.wireguard-tools}/bin/wg setconf wg0 "$TMPCONF"
    rm -f "$TMPCONF"

    # Assign address and bring up interface
    ${pkgs.iproute2}/bin/ip -n ${nsName} addr add "$WG_ADDRESS" dev wg0
    ${pkgs.iproute2}/bin/ip -n ${nsName} link set wg0 up

    # Set default route through WireGuard
    ${pkgs.iproute2}/bin/ip -n ${nsName} route add default dev wg0

    # Set up DNS inside the namespace
    mkdir -p /etc/netns/${nsName}
    echo "nameserver $WG_DNS" > /etc/netns/${nsName}/resolv.conf
  '';

  # Teardown script
  wgDown = pkgs.writeShellScript "wg-netns-down" ''
    ${pkgs.iproute2}/bin/ip -n ${nsName} link del wg0 2>/dev/null || true
    ${pkgs.iproute2}/bin/ip netns del ${nsName} 2>/dev/null || true
    rm -rf /etc/netns/${nsName}
  '';
in {
  options.modules.wireguard-netns = {
    enable = lib.mkEnableOption "WireGuard VPN network namespace";

    namespace = lib.mkOption {
      type = lib.types.str;
      default = "vpn";
      description = "Name of the network namespace.";
    };

    namespacePath = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = nsPath;
      description = "Absolute path to the network namespace file.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [pkgs.wireguard-tools];

    sops.secrets.wg_config = {
      owner = "root";
      group = "root";
      mode = "0400";
    };

    systemd.services.wg-netns = {
      description = "WireGuard VPN Network Namespace";
      after = ["network-online.target" "sops-nix.service"];
      wants = ["network-online.target"];
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = wgUp;
        ExecStop = wgDown;
      };
    };
  };
}
