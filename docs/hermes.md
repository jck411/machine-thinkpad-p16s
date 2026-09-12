# Hermes access

Launch **Hermes** from the application menu, or run `hermes-desktop`.
The `hermes-agent-desktop` AUR package builds Nous Research's Desktop app from
source and uses the system Electron runtime and shared Wayland flags.
Appearance uses the Nord theme imported through Desktop's VS Code Marketplace
theme picker.

Desktop's primary connection, **Home Hermes**, uses the existing VM 114 dashboard
at <http://192.168.1.114:9119>. Sign in with the dashboard account when prompted.
This address requires access to the home network. Browser access remains available
at <https://hermes.jackshome.com> through Cloudflare Access.

Penelope (`default`) and Karen (`homelab_shared`) are profiles on that VM.
The agent, providers, profiles, conversations, skills, and memory remain there.
Desktop uses a remote connection; its **This laptop** connection is unconfigured.
Select the VM connection when managing assistants.

The **Bots** tab provides upstream Bot Mode for existing profiles. Its canonical
Bot Chats are separate from Telegram conversations. Bot Mode does not merge
Honcho workspaces; cross-profile requests remain deliberate sharing between
assistants with separate memory domains.

Private connection and login state lives in `~/.config/Hermes/`, excluded from
dotfiles tracking. Settings are app-owned; do not put credentials in this repository.
The shared package declaration is in
[base.txt](../../dotfiles_hyprland/packages/base.txt).

Update the Desktop package through the workstation's install/update workflow
(`yay -S hermes-agent-desktop`). The AUR package manages client updates; the VM
backend has its own update procedure. Neither requires creating new profiles.
See the official [Desktop guide](https://hermes-agent.nousresearch.com/docs/user-guide/desktop)
and [Bot Mode guide](https://hermes-agent.nousresearch.com/docs/user-guide/bot-mode).

For credentials, settings, service maintenance, and recovery, follow
[Hermes operations](../../PROXMOX/docs/hermes.md).

Retained laptop data is private and inactive under
`~/.local/share/hermes-retired-state/`: `agent/` contains the previous local
settings and conversations; `desktop/` contains the desktop connection and login
state. These files are not needed for browser access and are not a server backup.
