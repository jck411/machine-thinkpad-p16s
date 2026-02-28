# Machine Control — ThinkPad P16s Gen 4

Single-machine orchestrator for a ThinkPad P16s Gen 4 running EndeavourOS (Arch) + Hyprland.

This repo is the **control plane** for this specific box. Shared configs and package lists live in [`dotfiles_hyprland`](https://github.com/jck411/dotfiles_hyprland) — this repo only calls into it.

## Hardware

| Spec | Value |
|------|-------|
| Model | Lenovo ThinkPad P16s Gen 4 AMD (21MF) |
| CPU | AMD Ryzen AI 9 HX PRO 370 (2.00–5.10 GHz, 12C/24T) |
| GPU | AMD Radeon 880M Integrated |
| Display | 16" WUXGA (1920x1200) IPS, 500 nits, 60Hz |
| RAM | 96 GB DDR5-5600 (2 × 48 GB SODIMM) |
| Storage | 1 TB NVMe Gen4 TLC Opal |
| Wi-Fi | MediaTek Wi-Fi 7 MT7925 2×2 BE + Bluetooth 5.4 |
| Battery | 86 Wh, 100W USB-C charger, Rapid Charge |
| Extras | Smart card reader, TPM 2.0, 5MP IR camera |
| OS | EndeavourOS (Arch) |

## Quick Start

### Fresh machine (from nothing)
```bash
# After EndeavourOS install, connect to Wi-Fi, then:
curl -O https://raw.githubusercontent.com/jck411/machine-thinkpad-p16s/main/bootstrap.sh
chmod +x bootstrap.sh && ./bootstrap.sh
```

### Full setup (repos already cloned)
```bash
./setup.sh
```
This will:
1. Clone `dotfiles_hyprland` to `~/REPOS/` if missing
2. Install all declared packages (base + thinkpad-p16s-gen4)
3. Symlink all configs (host profile: thinkpad-p16s-gen4)
4. Enable systemd services

### Check status
```bash
./update.sh                 # Pull repos, check packages/services
```

### Full update (pull + system upgrade)
```bash
./update.sh full            # Pull, check packages, check services, pacman -Syu
```

### Run individual steps
```bash
./setup.sh dotfiles         # Just clone/pull dotfiles
./setup.sh packages         # Just install missing packages
./setup.sh configs          # Just link configs
./setup.sh services         # Just enable services
./update.sh system          # Just run pacman -Syu + yay -Sua
```

## Structure

```
machine-thinkpad-p16s/
├── setup.sh                # Full bootstrap (idempotent)
├── update.sh               # Pull + reconcile + optional system update
├── system/
│   ├── services.txt        # systemd units to enable
│   ├── sysctl.conf         # kernel parameter overrides
│   └── networkmanager/     # NM config drops
├── secrets/                # gitignored — credentials mount point
└── state/                  # gitignored — runtime logs
```

## Relationship to dotfiles_hyprland

```
machine-thinkpad-p16s/       dotfiles_hyprland/
├── setup.sh ───────────▶    ├── packages.sh (install thinkpad-p16s-gen4)
│                             ├── install.sh (link configs)
├── update.sh ──────────▶    ├── packages.sh (status thinkpad-p16s-gen4)
│                             ├── sync.sh (check symlinks)
│                             ├── packages/
│                             │   ├── base.txt
│                             │   └── thinkpad-p16s-gen4.txt
│                             └── config/hypr/hosts/
│                                 └── thinkpad-p16s-gen4.conf
```

This repo **calls** dotfiles scripts. The agent also **edits dotfiles directly** when making configuration changes.

## Security

- `secrets/` is gitignored — never committed
- No tokens, API keys, or credentials in tracked files
- SSH keys, rclone configs, etc. are managed outside both repos
