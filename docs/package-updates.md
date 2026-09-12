# Package updates

Ask the agent to review and apply updates. `./update.sh system` and
`~/.config/scripts/update-system.sh` run the same terminal-based updater.
The weekly shell check only reminds; it never starts an upgrade.

The updater requires a terminal, forces yay's confirmation prompts, and displays
all available AUR build-file diffs before building. Package-sync also refuses
unattended AUR installations. Sudo uses normal authentication; update scripts
do not read stored passwords. Logs and the last completed-update marker live in
`~/.local/state/machine-update/`.

## Required review

1. Read [Arch news](https://archlinux.org/news/) and relevant upstream security
   advisories. Check repository origins, required package signatures, available
   disk space, and service implications. Do not reboot or disrupt remote access
   without authorization and a recovery path.
2. Prefer signed Arch/EndeavourOS packages. For AUR packages, inspect the current
   maintainer, upstream source, and every changed tracked file, including
   `PKGBUILD`, patches, launchers, and `.install` hooks. Review new AUR dependencies
   too. A previously downloaded checkout or empty diff is not proof of review;
   inspect complete files when the installed/reviewed baseline is unknown.
3. Review before invoking `makepkg`, sourcing a `PKGBUILD`, or allowing build
   scripts to execute. Stop on unexplained maintainership changes, obfuscation,
   unrelated downloads, credential access, or package-manager commands in root
   install hooks. Validate checksums and upstream signatures where supplied;
   never disable signature checks to get past an error.
4. Use yay's review prompts and build as an unprivileged user. Do not use
   `--noconfirm`, pipe automatic yes answers, or reintroduce stored-password
   wrappers for AUR operations. Keep dependency lockfiles intact and disable
   dependency lifecycle scripts when supported; approve necessary build hooks
   individually. Isolate unfamiliar builds from credentials before running them.
5. Apply a complete repository upgrade; avoid partial upgrades or indefinite
   holds on security-sensitive applications. Review any replacements/removals.
   Resolve `.pacnew` files, required rebuilds, and failed services. Check affected
   applications and remote-management access. Report a required reboot rather
   than performing one automatically.

Yay provides a review opportunity, not malware detection or a security sandbox.
Signed packages, clean incident-list checks, popularity, and passing tests do not
guarantee that software is safe. See [Arch's AUR review guidance](https://wiki.archlinux.org/title/Arch_User_Repository#Verify_the_PKGBUILD).
