# T3 Code remote environments

Sachiel installs the official desktop app with the `t3-code@nightly` Homebrew
cask. Open `/Applications/T3 Code (Nightly).app`. The app uses its own updater.

Both Linux backends use the `t3-code-nightly` package from
[omarcresp/t3code-flake](https://github.com/omarcresp/t3code-flake).
It packages official release binaries. `flake.lock` pins the version.
Run `nix flake update t3code` and rebuild the hosts to update it.
Do not use T3's service installer or updater on Linux.

| Environment | Private endpoint | Backend |
| --- | --- | --- |
| Adam | `https://adam.zekurio.me` | Adam's loopback port 3773 |
| Lilith | `https://lilith.zekurio.me` | Lilith's Tailscale port 3773 |

AdGuard must resolve both names to `10.0.0.2`. Caddy accepts only LAN and
tailnet clients. Lilith accepts backend connections only from Adam's Tailscale
IPv4 address. Both T3 environments still require device pairing.

Use separate hostnames. T3 replaces URL paths when it builds API URLs,
so `/adam` and `/lilith` prefixes do not work.

## First use

Each backend runs as `zekurio`, with the same home, file permissions, and sudo
access as a normal SSH session. Projects can use `~/Git`. T3 state lives in
`~/.t3`. Agents use the account's Git config, Codex login, and shared skills.
The service includes the user's package paths. On Lilith it uses the configured
1Password SSH agent socket, which requires 1Password to be available.

An SSH agent forwarded from Sachiel belongs to that SSH session. The T3 service
does not inherit it. On Adam, outbound SSH uses the account's local SSH keys
unless a separate persistent agent is configured.

Sign in to Codex on each host:

```sh
ssh -t adam 'codex login --device-auth'
ssh -t lilith 'codex login --device-auth'
```

Generate a short-lived pairing token on the host:

```sh
ssh adam 't3 pair'
ssh lilith 't3 pair'
```

In the Mac app, open Settings > Connections > Add environment. Enter the
private HTTPS endpoint and its token. The CLI may print a loopback or tailnet
URL; use the Caddy endpoint from the table instead. Keep tokens out of Git.

Clone projects as `zekurio`. Adam's system rebuilds still use the GitHub flake,
not development checkouts.

## Service and previews

The system service starts at boot and survives client disconnects. Check it
from the normal administrative account:

```sh
ssh adam 'systemctl status t3code'
ssh adam 'sudo journalctl -u t3code --since "10 minutes ago"'
```

Agents have the same access to home directories, shares, and mounted files as
`zekurio`. Use Nix development shells for project dependencies.

Web previews use separate SSH tunnels. Bind the dev server to loopback on its
host. For example, run one of these commands on the Mac:

```sh
ssh -N -o ExitOnForwardFailure=yes -L 127.0.0.1:3000:127.0.0.1:3000 adam
ssh -N -o ExitOnForwardFailure=yes -L 127.0.0.1:3001:127.0.0.1:3000 lilith
```

Open `http://localhost:3000` for Adam or `http://localhost:3001` for Lilith.
Use a separate port for each concurrent worktree. No Caddy preview routes or
public development ports are needed.
