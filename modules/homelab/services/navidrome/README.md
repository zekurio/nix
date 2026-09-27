Navidrome serves the Beets-managed library at `/tank/media/music` through
`https://music.zekurio.me`. Caddy restricts access to the LAN and tailnet.
The native port listens only on loopback.

The service can read the shared library, but its systemd sandbox mounts it
read-only. Beets remains responsible for tags, lyrics, and covers. Navidrome
checks for library changes every five minutes and prefers local cover files
and embedded artwork.

On the first visit, create the administrator account. In Feishin, add a
Navidrome server with `https://music.zekurio.me` and that account's credentials.
State lives in `/var/lib/navidrome`. Use
`journalctl -u navidrome.service` to inspect startup and scanner logs.
