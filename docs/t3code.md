# T3 Code remote environments

The Mac app and both Linux backends use the T3 package pinned by `llm-agents`.
Update them through `flake.lock` and rebuild each host. Do not use T3's service
installer or app updater for these Nix-managed installations.

| Environment | Private endpoint | Backend |
| --- | --- | --- |
| Adam | `https://t3.zekurio.me` | Adam's loopback port 3773 |
| Lilith | `https://t3-lilith.zekurio.me` | Lilith's Tailscale port 3773 |

AdGuard must resolve both names to `10.0.0.2`. Caddy accepts only LAN and
tailnet clients. Lilith accepts backend connections only from Adam's Tailscale
IPv4 address. Both T3 environments still require device pairing.

Use separate hostnames. T3 0.0.38 replaces URL paths when it builds API URLs,
so `/adam` and `/lilith` prefixes do not work.

## First use

The `t3code` account owns each environment. Its home is `/var/lib/t3code` and
projects belong in `/var/lib/t3code/projects`. It has SSH access with the
repo's pinned keys, but no sudo rights. Provider credentials are separate from
the `zekurio` account. Shared agent skills are available under `.agents/skills`.

Sign in to Codex on each host:

```sh
ssh -t t3code@adam 'codex login --device-auth'
ssh -t t3code@lilith 'codex login --device-auth'
```

Generate a short-lived pairing token on the host:

```sh
ssh t3code@adam 't3 pair'
ssh t3code@lilith 't3 pair'
```

In the Mac app, open Settings > Connections > Add environment. Enter the
private HTTPS endpoint and its token. The CLI may print a loopback or tailnet
URL; use the Caddy endpoint from the table instead. Keep tokens out of Git.

Clone projects as `t3code`. Authenticate Git for that account when a project
needs private repository access. Adam's system rebuilds still use the GitHub
flake, not these development checkouts.

## Service and previews

The system service starts at boot and survives client disconnects. Check it
from the normal administrative account:

```sh
ssh adam 'systemctl status t3code'
ssh adam 'sudo journalctl -u t3code --since "10 minutes ago"'
```

The service can write to its own home and private temporary directory. It
cannot access `/home`, `/tank`, or `/mnt/downloads`. Build project dependencies
with Nix development shells inside the project.

Web previews use separate SSH tunnels. Bind the dev server to loopback on its
host. For example, run one of these commands on the Mac:

```sh
ssh -N -o ExitOnForwardFailure=yes -L 127.0.0.1:3000:127.0.0.1:3000 adam
ssh -N -o ExitOnForwardFailure=yes -L 127.0.0.1:3001:127.0.0.1:3000 lilith
```

Open `http://localhost:3000` for Adam or `http://localhost:3001` for Lilith.
Use a separate port for each concurrent worktree. No Caddy preview routes or
public development ports are needed.
