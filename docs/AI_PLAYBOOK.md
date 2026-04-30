# AI Playbook — machine-thinkpad-p16s

Complete agent and coding guidelines for this repository.

---

## Architecture

- Workspace entry point — all repos live under `~/REPOS/`
- Read each repo's `.github/copilot-instructions.md` before editing it
- Host profile key: `thinkpad-p16s-gen4`
- Secrets and credentials live in `~/REPOS/symlinked-env/.env` (single master file) — check there before prompting the user (e.g. `SUDO_PASSWORD` for sudo prompts)
- `secrets/.env` is a symlink → `~/REPOS/symlinked-env/.env`; all other repo `.env` files are symlinks too

## Routing

| What                        | Where                                              |
|-----------------------------|---------------------------------------------------|
| Common apps                 | `dotfiles_hyprland/packages/base.txt`             |
| Hardware-specific apps      | `dotfiles_hyprland/packages/thinkpad-p16s-gen4.txt` |
| Dotfiles / app configs      | `dotfiles_hyprland/config/`                       |
| Systemd services, sysctl    | `system/` in this repo                            |
| Secrets                     | `~/REPOS/symlinked-env/.env` (master); symlinked into every repo |

## Boundaries

- Propagate changes to ALL affected repos — no partial updates
- Never commit secrets, tokens, or credentials
- Never duplicate configs that belong in `dotfiles_hyprland`
- Non-destructive by default — confirm before destructive actions
- All scripts must be idempotent

---

## Install / Update Workflow

> **Always install through the LLM.** Never install packages manually outside this agent — the workflow below ensures package lists, configs, symlinks, and backups all stay in sync.

When asked to install or update any app, follow these steps in order:

1. **Verify the app is real** — search online if unfamiliar; never refuse due to unfamiliarity.
2. **Check if already installed** — `which <app>`, `pacman -Q <pkg>`, check `/opt/`, `~/.local/bin/`, `~/.local/share/applications/`
3. **Determine install type** — pacman/yay → `yay -S <pkg>`; tarball → `/opt/<App>/`; Python → `uv`
4. **Compare versions** if already installed — same: confirm before reinstalling; newer: proceed
5. **Install or update** — confirm before overwriting `/opt/` or system paths
6. **Clean up** — remove old dirs, leftover tarballs, stale `.desktop` entries
7. **Update docs** — add to `dotfiles_hyprland/packages/base.txt` or `thinkpad-p16s-gen4.txt`; annotate manual installs with `# [MANUAL]`; add config to `dotfiles_hyprland/config/` + `install.sh` if applicable
8. **Commit and push** both repos

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
