# Hermes Desktop

Launch **Hermes** from Rofi or run `hermes desktop`. It always connects to the
home agent through `https://hermes.jackshome.com`, at home or away. No automatic
LAN switching or fallback is configured. **Local** runs an agent on the laptop;
it does not select the home server's LAN address.

Sessions, models, tools, and Telegram stay on the server. Use browser sign-in
in the gateway settings and complete Cloudflare Access if prompted, then the
dashboard login. The app's login session is separate from your web browser.
See [server credentials and operations](../../PROXMOX/docs/hermes.md).
Edit the home agent's settings and profile SOUL files through the connected UI
or directly on the VM. They are not mirrored in a laptop repository, and service
repair preserves UI edits. This repository owns the desktop client and connection.

**Extra gateway headers** must contain `CF-Access-Client-Id` and
`CF-Access-Client-Secret` from service token `hermes-desktop-thinkpad-p16s`,
authorized only for Hermes. They authenticate HTTP and WebSocket traffic;
dashboard login is still required. The token is private in
`secrets/hermes-cloudflare.json` and the app's connection settings. Renew its
one-year lifetime before expiry using [Cloudflare Service credentials](https://developers.cloudflare.com/cloudflare-one/access-controls/service-credentials/service-tokens/).

`setup.sh packages` includes the desktop installation. To install it separately:

```bash
./scripts/install-hermes-desktop.sh
```

The script installs upstream `main`, builds the desktop, registers its
launcher, and configures Wayland/IME. It seeds the URL from the Hermes
`public_url` in `NETWORK/lxc/services.json`, preserving existing connections.
A fresh installation still needs the service-token headers and dashboard login.

The runtime lives in `~/.hermes/hermes-agent/`, with commands in `~/.local/bin/`.
Hermes owns its settings, sessions, and credentials in `~/.hermes/` and
`~/.config/Hermes/`; neither directory belongs in Git or dotfiles sync.
Updates follow upstream `main`. Use `hermes update --backup` through the agent
install workflow; verify desktop and server versions, connection, and model
routes together after updating. Release tags do not define the update channel.

Automatic update backups are disabled in the laptop's app-owned configuration.
The explicit `--backup` flag still creates a Hermes-state ZIP and retains the
latest five pre-update ZIPs. Desktop connection/login state in `~/.config/Hermes/`
is outside that backup.
