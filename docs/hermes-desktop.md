# Hermes Desktop

Launch **Hermes** from Rofi or run `hermes desktop`. The desktop connects to
the existing home agent; sessions, models, tools, and Telegram stay on the server.
The connection requires access to the home LAN. Server access and credentials
are documented in [Hermes operations](../../PROXMOX/docs/hermes.md).

`setup.sh packages` includes the desktop installation. To install it separately:

```bash
./scripts/install-hermes-desktop.sh
```

The script installs the pinned official release through its uv-based installer,
builds the Linux desktop, and registers the upstream launcher and icon. Wayland
and IME flags are applied through Hermes's own settings. The initial gateway URL
comes from `NETWORK/lxc/services.json`; existing connection settings are preserved.

The runtime lives in `~/.hermes/hermes-agent/`, with commands in `~/.local/bin/`.
Hermes owns its settings, sessions, and credentials in `~/.hermes/` and
`~/.config/Hermes/`; neither directory belongs in Git or dotfiles sync.
Updates go through the agent install workflow; desktop and server versions must
be checked together before updating.
