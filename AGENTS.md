# GitHub Copilot Instructions

**→ See [`docs/AI_PLAYBOOK.md`](../docs/AI_PLAYBOOK.md) for full routing, workflows, and implementation details.**

Control plane for a ThinkPad P16s Gen 4 AMD running EndeavourOS (Arch) + Hyprland.

## Non-Negotiable Rules

1. **Prefer the best solution** over the smallest diff; rewrite when it's cleaner than patching.
2. **No legacy code**: when replacing behavior, remove old code/files/configs—never leave dead paths.
3. **Repo-wide sweep** for leftovers after changes: old names, config keys, dead references, unused deps.
4. **Keep the codebase shrinking**: delete what's no longer needed; no parallel implementations.
5. **Docs are the source of truth** and must stay concise—**no duplicated documentation**, link instead.
6. **All substantial docs** live in `docs/`; keep repo root minimal.
7. **Update docs** every time behavior changes.
8. **Maintain a strong `.gitignore`**: never commit secrets, tokens, credentials, or machine-specific files.
9. **Verify before acting**: if an app or product is unfamiliar, search online first; never refuse due to unfamiliarity.
10. **Propagate changes** to ALL affected repos—no partial updates.
11. **All installs go through the LLM**: never install manually outside this agent. Every install must follow the workflow in `docs/AI_PLAYBOOK.md` so package lists, configs, and backups stay in sync.
12. **Keep machine credentials local** in the Git-ignored `secrets/.env`; never source or copy unrelated repository credentials.

## Required Post-Change Checklist

- [ ] Old files, dirs, and stale entries removed—no dead leftovers
- [ ] Repo-wide search for leftovers (names, config keys, references)
- [ ] Docs updated in `docs/` (concise, non-duplicative)
- [ ] `.gitignore` updated for any new sensitive/local artifacts
- [ ] Both repos committed and pushed

## Project Structure

```
system/          — systemd services, sysctl, system configs
secrets/         — gitignored credentials and tokens
state/           — gitignored runtime state
docs/            — all substantial documentation
bootstrap.sh     — initial machine setup (curl from fresh install)
setup.sh         — full idempotent setup (packages, configs, services)
update.sh        — pull repos, reconcile, optional system upgrade
```

## Tech Stack

- **OS**: EndeavourOS (Arch Linux) + Hyprland (Wayland)
- **Shell**: Bash (`#!/bin/bash`, `set -e`; no `set -e` for long-running daemons)
- **Package manager**: pacman / yay (never apt or dnf)
- **Python**: uv (never raw pip)

## Git

- Commit and push after every completed change
- Imperative, lowercase, no period
- Push directly to `main`—no branches or PRs

---

**For routing rules, install workflow, Hyprland gotchas, and full guidelines:**
**→ [`docs/AI_PLAYBOOK.md`](../docs/AI_PLAYBOOK.md)**
