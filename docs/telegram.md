# Telegram

Telegram Desktop uses the official Arch `telegram-desktop` package. Its package
declaration lives in `dotfiles_hyprland/packages/base.txt`.
Launch **Telegram** from Rofi, sign in with your existing Telegram
account. For the family assistant, follow [Hermes access](../../PROXMOX/docs/hermes.md#access).

The packaged desktop entry supplies launcher and `tg://` integration. Settings
and authenticated session data stay local in `~/.local/share/TelegramDesktop/`;
this directory is excluded from Git in the dotfiles repository.
