# Package updates

`./update.sh system` and `~/.config/scripts/update-system.sh` run the same
unattended official-repository and AUR upgrade. No terminal or answers are needed.
The weekly shell check only reminds; it does not schedule upgrades.

## Build isolation

All repository-managed AUR operations use `scripts/aur.sh`, including new
applications installed through dotfiles `packages.sh`. Use this entry point
instead of invoking yay or makepkg directly when building packages.

The runner uses yay 13's `--makepkg` setting to execute **every** makepkg call
through `isolated-makepkg.py`, including metadata queries, source preparation,
verification, build, and packaging. Bubblewrap 0.12 creates disposable mount,
user, PID, IPC, and network namespaces. Builds get:

- A fresh home and environment, with no host credentials, SSH/GPG agents,
  desktop sockets, host processes, or inherited file descriptors beyond output.
- Read-only installed tools, package databases, public system configuration,
  and checkout Git metadata. Only the current package workspace is writable
  on the host; temporary files and the build home disappear after each call.
- Public source-verification keys exported from a dedicated keyring. The
  user's personal GPG keyring is never mounted.
- Outbound networking through slirp4netns 1.3.5, with host loopback forwarding
  disabled. Host networking configuration is unchanged. This is not an outbound
  firewall: Internet and LAN destinations remain reachable for downloads.
- No capabilities or privilege elevation. Sudo cannot work inside the build.

Missing isolation tools or failed sandbox setup stop the operation; there is
no unsandboxed fallback. Dependencies and completed packages are installed by
the host package manager outside the build sandbox.

Builds live in `~/.cache/machine-aur/builds/<package-base>/`; the public keyring
lives in `~/.local/state/machine-update/aur-keys/`. User makepkg overrides and
shared user build caches are not exposed. Builds requiring undeclared software
outside `/usr` or access to personal files fail and need their recipe corrected.

**Scope:** this protects the host from build-time code. Installing an AUR package
still trusts its files and root install hooks, and running it trusts its program.
This is a shared-kernel sandbox, not a VM or malware detector. Review new
applications before adding them; unattended updates accept subsequent recipes.

## Authentication and automatic answers

Only the host installer reads `SUDO_PASSWORD` from this repository's Git-ignored
`secrets/.env`, owned by the current user with permissions `600`. Authentication
uses standard input for every privileged invocation, including after long
builds. Missing or invalid credentials fail without asking for a password.

Routine updates upgrade all eligible packages, reuse package workspaces, skip
clean/diff/editor menus, accept normal transaction defaults and yay-detected
conflicts, and import declared source-signing keys. Checksums and signatures
remain enabled. Build dependencies and orphaned packages are retained.

## Failures and completion

The updater disconnects terminal input and disables Git credential prompts.
Unresolvable conflicts, failed builds, and integrity failures stop the update.
It does not force file overwrites, merge `.pacnew` files, or reboot.

Logs, status, and the last completed-update marker live in
`~/.local/state/machine-update/`. Concurrent updates are refused. Success is
recorded only after querying for remaining updates. Postflight checks report
configuration merges, library rebuilds, orphans, and failed system services.

Implementation references: [yay 13.0.1](https://github.com/Jguer/yay/blob/v13.0.1/pkg/settings/exe/cmd_builder.go),
[Bubblewrap 0.12](https://github.com/containers/bubblewrap/blob/v0.12.0/README.md),
and [slirp4netns](https://github.com/rootless-containers/slirp4netns/blob/v1.3.5/slirp4netns.1.md).
