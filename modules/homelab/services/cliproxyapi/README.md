# Private AI proxy

Adam serves CLIProxyAPI at `https://ai.zekurio.me/v1`.
Caddy allows only LAN and tailnet clients. The backend binds to loopback.
The router's private DNS must map `ai.zekurio.me` to `10.0.0.2`.

The service creates two random keys on its first start. Read the app key with:

```sh
ssh adam 'sudo cat /var/lib/cliproxyapi/api-key'
```

Use this key in apps that accept an OpenAI-compatible base URL.
Model names come from `/v1/models` after account login.
App support depends on the API methods that each app uses.

## Add a ChatGPT account

Run this command and follow the device login link:

```sh
ssh -t adam 'sudo -u cliproxyapi cli-proxy-api -config /var/lib/cliproxyapi/config.yaml -codex-device-login -no-browser'
```

Repeat for each account. Enable device code login in the account if required.
The proxy watches its auth directory and loads new accounts without a restart.
Requests use round-robin account selection and retry other eligible accounts.
The proxy does not change the requested model when an account reaches its limit.

## Admin panel

Open `https://ai.zekurio.me/management.html`. Use the separate admin key:

```sh
ssh adam 'sudo cat /var/lib/cliproxyapi/management-key'
```

The backend listens only on loopback. Remote management is enabled because
Caddy forwards the client IP. Caddy applies the private network rule first.
The admin key remains required. Do not use it as an app key.
The panel downloads on first access. Automatic panel updates are disabled.

## State and updates

Back up `/var/lib/cliproxyapi` securely. It contains the client key, admin key,
and account refresh tokens. These files are private host state, not SOPS inputs.
The service writes its config from Nix settings on every start. Panel config
changes are temporary. Account logins remain across restarts.

The package uses the upstream portable Linux build without dynamic plugins.
Update its version and checksum together. The flake inputs do not need an update.

## Codex client

Add a provider to the client's `config.toml`:

```toml
model_provider = "adam"

[model_providers.adam]
name = "Adam"
base_url = "https://ai.zekurio.me/v1"
env_key = "ADAM_AI_API_KEY"
wire_api = "responses"
```

Set `ADAM_AI_API_KEY` to the app key in the client's environment.
Select a model returned by `/v1/models`. Restart the client after changing its
environment. Test a separate session before changing an active task.
