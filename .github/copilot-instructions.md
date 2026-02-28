# Copilot Instructions — machine-thinkpad-p16s

Control plane for a ThinkPad P16s Gen 4 AMD running EndeavourOS (Arch) + Hyprland.

## Core Operating Principles

- **Prefer the cleanest approach** — rewrite or restructure over layering fixes on messy structure
- **Zero legacy leftovers** — after any change, remove stale files, old dirs, dead `.desktop` entries, unused package list entries, and outdated comments
- **Verify before acting** — if an app or product is unfamiliar, search online to confirm it exists; never refuse solely due to unfamiliarity
- **Docs must stay current** — update `packages/*.txt`, `README`, and instructions every time behavior changes; no stale or duplicate docs
- **Protect sensitive files** — never commit secrets, tokens, credentials, or machine-specific local files; when in doubt, add to `.gitignore`

## Architecture

- Workspace entry point — all repos live under `~/REPOS/`
- Read each repo's `.github/copilot-instructions.md` before editing it
- Host profile key: `thinkpad-p16s-gen4`

## Routing

- Common apps → `dotfiles_hyprland/packages/base.txt`
- Hardware-specific apps → `dotfiles_hyprland/packages/thinkpad-p16s-gen4.txt`
- Dotfiles and app configs → `dotfiles_hyprland/config/`
- Systemd services, sysctl → `system/` in this repo
- Secrets → `secrets/` in this repo (gitignored)

## Boundaries

- Propagate changes to ALL affected repos — no partial updates
- Never commit secrets, tokens, or credentials
- Never duplicate configs that belong in `dotfiles_hyprland`
- Non-destructive by default — confirm before destructive actions
- All scripts must be idempotent

## Install / Update Workflow

When asked to install or update any app, always follow these steps in order:

1. **Verify the app is real** — if unfamiliar, search online to confirm it exists before doing anything else. Never refuse solely due to unfamiliarity.

2. **Check if already installed:**
   - `which <app>` — is it on PATH?
   - `pacman -Q <pkg>` — is it in pacman?
   - Check `/opt/`, `~/.local/bin/`, `~/.local/share/applications/` for manual installs

3. **Determine install type:**
   - pacman/yay package → use `yay -S <pkg>`
   - tarball/manual → extract to `/opt/<App>/`, update `.desktop` if needed
   - Python tool → use `uv`

4. **If already installed, compare versions:**
   - Get current: `<app> --version` or check the binary/dir
   - Get new: from tarball filename or package info
   - Same version → confirm with user before reinstalling
   - Newer version → proceed as update

5. **Install or update:**
   - Confirm with user before overwriting anything in `/opt/` or system paths
   - For tarball updates: back up or remove old `/opt/<App>/` dir, extract new, verify binary works
   - For pacman: `yay -S <pkg>` handles upgrades automatically

6. **Clean up:**
   - Remove old extracted dirs, leftover tarballs in `~/Downloads/` (ask first)
   - Remove stale `.desktop` entries if app moved or renamed

7. **Update documentation:**
   - App for all machines → `dotfiles_hyprland/packages/base.txt`
   - App specific to this machine only → `dotfiles_hyprland/packages/thinkpad-p16s-gen4.txt`
   - If manually installed (tarball), comment out the entry and annotate: `# myapp  # [MANUAL] tarball from <source> — installed to /opt/MyApp/`
   - If it has config, add to `dotfiles_hyprland/config/` and update `install.sh`

8. **Commit and push** both repos if files changed

## After Change Checklist

Every meaningful change must satisfy:
- [ ] Old files, dirs, and stale entries removed — no dead leftovers
- [ ] `dotfiles_hyprland/packages/*.txt` updated to reflect current state
- [ ] Docs and instructions updated if behavior changed
- [ ] `.gitignore` updated for any new sensitive or local artifacts
- [ ] Both repos committed and pushed

## Git

- Commit and push after every completed change
- Imperative, lowercase, no period
- Push directly to `main` — no branches or PRs

## Python

- **Always use `uv`** for Python — never raw `pip`, `pip install`, or `python -m pip`
- Virtual envs: `uv venv`, install deps: `uv pip install`, run scripts: `uv run`
- Project deps: `uv add <pkg>` (updates `pyproject.toml` automatically)
- If a `.venv` exists, `uv` picks it up — no need to activate manually

## Shell

- Use `#!/bin/bash` and `set -e`
- Target Arch Linux — use `pacman`/`yay`, not apt or dnf
