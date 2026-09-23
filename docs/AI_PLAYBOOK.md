# AI Playbook — machine-thinkpad-p16s

Complete agent and coding guidelines for this repository.

---

## Architecture

- Workspace entry point — all repos live under `~/REPOS/`
- Read each repository's root `AGENTS.md` before editing it
- Host profile key: `thinkpad-p16s-gen4`
- Machine-only credentials live in the Git-ignored `secrets/.env`.
- Each repository owns its own Git-ignored environment files; never share them through symlinks or shell-wide exports.

## Routing

| What                        | Where                                              |
|-----------------------------|---------------------------------------------------|
| Common apps                 | `dotfiles_hyprland/packages/base.txt`             |
| Hardware-specific apps      | `dotfiles_hyprland/packages/thinkpad-p16s-gen4.txt` |
| Dotfiles / app configs      | `dotfiles_hyprland/config/`                       |
| Systemd services, sysctl    | `system/` in this repo                            |
| Machine secrets             | `secrets/.env` in this repo                        |

## Boundaries

- Propagate changes to ALL affected repos — no partial updates
- Never commit secrets, tokens, or credentials
- Never duplicate configs that belong in `dotfiles_hyprland`
- Non-destructive by default — confirm before destructive actions
- All scripts must be idempotent

---

## Install / Update Workflow

> **Always install through the LLM.** Never install packages manually outside this agent — the workflow below ensures package lists, configs, symlinks, and backups all stay in sync.

Follow the [package update workflow](package-updates.md). Routine updates are
unattended, including AUR builds and their dependencies. Review new applications
before adding them to package declarations.

When asked to install or update any app, follow these steps in order:

1. **Verify the app is real** — search online if unfamiliar; never refuse due to unfamiliarity.
2. **Check if already installed** — `which <app>`, `pacman -Q <pkg>`, check `/opt/`, `~/.local/bin/`, `~/.local/share/applications/`
3. **Determine install type** — pacman/yay → `yay -S <pkg>`; Python → `uv`. Tarball installs to `/opt/<App>/` are deprecated — prefer AUR/pacman packages when available.
4. **Compare versions** if already installed — same: confirm before reinstalling; newer: proceed
5. **Install or update** — confirm before overwriting system paths
6. **Clean up** — remove old dirs, stale `.desktop` entries
7. **Update docs** — add to `dotfiles_hyprland/packages/base.txt` or `thinkpad-p16s-gen4.txt`; annotate manual installs with `# [MANUAL]`; add config to `dotfiles_hyprland/config/` + `install.sh` if applicable
8. **Commit and push** both repos

---

## Uninstall Workflow

1. Remove package declarations and setup/install hooks from every affected repo.
2. Identify package-owned files with `pacman -Qo`; preview removal with
   `pacman -Rs --print-format '%n %v' <package>`, then uninstall the app and
   dependencies used only by it through pacman.
3. Remove custom desktop entries, MIME associations, file-manager actions,
   keybindings, shell wrappers, autostart entries, services, and editor extensions.
4. Remove app-specific download/build caches. Refresh the desktop database and
   invalidate Rofi's desktop cache after launcher changes.
5. Preserve conversations, credentials, and other user data unless deletion is
   explicitly authorized. Distinguish retained data from executable integrations.
6. Search affected repos and live integration locations again; verify the package,
   commands, launch entries, and processes are absent. Inspect other references
   before removing them: a separate service may still use the same provider.
7. Validate config syntax and symlinks, update relevant docs, then commit and push
   task-scoped changes.

---

## Implementation Standards

### Shell

- Use `#!/bin/bash` and `set -e`
- Target Arch Linux — use `pacman`/`yay`, not apt or dnf
- Long-running daemons: do NOT use `set -e` — transient errors will kill the loop

### Python

- **Always use `uv`** — never raw `pip`, `pip install`, or `python -m pip`
- Virtual envs: `uv venv`; install deps: `uv pip install`; run scripts: `uv run`
- Project deps: `uv add <pkg>` (updates `pyproject.toml` automatically)

---

## Hyprland + Waybar Gotchas

- **Waybar `mode: "hide"` does NOT work on Hyprland** — it requires Sway IPC for hover-to-reveal. On Hyprland it just applies a CSS class (`.hidden`) with no mouse interaction.
- **Correct autohide on Hyprland**: poll `hyprctl cursorpos`, send `SIGUSR1` (show) / `SIGUSR2` (hide) to waybar. Use `start_hidden: true`, `on-sigusr1: "show"`, `on-sigusr2: "hide"` in config. No `mode` key.
- **`pkill` matches substrings** — `pkill -SIGUSR1 waybar` also kills scripts containing "waybar". Always use `pkill -x` for exact binary name matching.
- **Research before implementing** — check official docs to confirm features work on Hyprland specifically, not just Sway.

## ThinkPad Hardware Gotchas

- **MediaTek Bluetooth may boot without a BlueZ controller**: if `rfkill` sees `hci*` but `bluetoothctl show` says `No default controller available`, the `btusb`/`btmtk` init likely timed out. `bluetooth-controller-recover.service` reloads `btusb` at boot only when BlueZ has no controller.
