# Package updates

`./update.sh system` and `~/.config/scripts/update-system.sh` run the same
unattended official-repository and AUR upgrade. No terminal or answers are needed.
The weekly shell check only reminds; it does not schedule upgrades.

Sudo reads `SUDO_PASSWORD` from this repository's Git-ignored `secrets/.env`,
which must be owned by the current user with permissions `600`. Each privileged
invocation authenticates over standard input, including after long builds.
Credentials are not exported to yay or build processes. Missing or invalid
credentials fail the update without asking for a password.

## Automatic answers

- Upgrade all eligible packages; exclude none.
- Reuse build caches; skip clean-build, diff, and editor menus.
- Accept normal pacman transaction defaults, replacements, and yay-detected
  package conflicts; choose the default dependency provider.
- Import AUR-declared source-signing keys; keep checksum and signature checks.
- Keep build dependencies and orphaned packages.

These settings use [yay 13's unattended options](https://github.com/Jguer/yay/blob/v13.0.1/doc/yay.8).
AUR updates execute community build scripts without interactive review. Review
new applications before declaring/installing them through `packages.sh`.

## Failures and completion

The updater disconnects terminal input and disables Git credential prompts.
Unresolvable conflicts, failed builds, signature errors, or unexpected input
requirements fail instead of waiting for an answer. It does not force file
overwrites, disable integrity checks, merge `.pacnew` files, or reboot.

Logs, status, and the last completed-update marker live in
`~/.local/state/machine-update/`. Concurrent updates are refused. Success is
recorded only after querying for remaining updates. Postflight checks report
configuration merges, library rebuilds, orphans, and failed system services.
Check Arch news and the log when an update fails or reports warnings; rerun after
resolving the cause. An unattended update is not a guarantee that every future
package transition can be resolved automatically.
