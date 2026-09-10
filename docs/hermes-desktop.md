# Hermes Desktop

Launch **Hermes** from Rofi or run `hermes desktop`. The desktop connects to
the existing home agent; sessions, models, tools, and Telegram stay on the server.
The desktop connects through `https://hermes.jackshome.com`, at home or away.
In the desktop's gateway settings, use that URL and the browser sign-in option.
Complete Cloudflare Access and then the dashboard login in the app's sign-in
window. The app keeps its own login session, separate from your web browser;
sign in again when it expires. Server credentials are documented in
[Hermes operations](../../PROXMOX/docs/hermes.md).

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
