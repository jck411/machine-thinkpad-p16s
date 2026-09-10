# Hermes Desktop

Launch **Hermes** from Rofi or run `hermes desktop`. The desktop connects to
the existing home agent; sessions, models, tools, and Telegram stay on the server.
The desktop connects through `https://hermes.jackshome.com`, at home or away.
In the desktop's gateway settings, use that URL and the browser sign-in option.
Complete Cloudflare Access and then the dashboard login in the app's sign-in
window. The app keeps its own login session, separate from your web browser;
sign in again when it expires. Server credentials are documented in
[Hermes operations](../../PROXMOX/docs/hermes.md).

The remote connection's **Extra gateway headers** contain
`CF-Access-Client-Id` and `CF-Access-Client-Secret` for Cloudflare service token
`hermes-desktop-thinkpad-p16s`. Its Service Auth policy permits only the Hermes
application. These headers authenticate HTTP and WebSocket traffic; the
dashboard login remains required. Browser cookies alone do not authenticate
the desktop's WebSocket connection through Cloudflare Access.

The token is private in `secrets/hermes-cloudflare.json` and Hermes's app-owned
connection settings. Renew its one-year lifetime in Cloudflare Zero Trust →
Access → Service credentials before expiry; renewal preserves the credential.
See [Cloudflare service tokens](https://developers.cloudflare.com/cloudflare-one/access-controls/service-credentials/service-tokens/).

`setup.sh packages` includes the desktop installation. To install it separately:

```bash
./scripts/install-hermes-desktop.sh
```

The script installs the pinned official release through its uv-based installer,
builds the Linux desktop, and registers the upstream launcher and icon. Wayland
and IME flags are applied through Hermes's own settings. The initial gateway URL
comes from the Hermes `public_url` in `NETWORK/lxc/services.json`; existing
connection settings are preserved.

The runtime lives in `~/.hermes/hermes-agent/`, with commands in `~/.local/bin/`.
Hermes owns its settings, sessions, and credentials in `~/.hermes/` and
`~/.config/Hermes/`; neither directory belongs in Git or dotfiles sync.
Updates go through the agent install workflow; desktop and server versions must
be checked together before updating.
