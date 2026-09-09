# Telegram

Telegram Desktop uses the AUR `telegram-desktop-bin` package, which packages
Telegram's official self-contained binaries and updates through yay. Its package
declaration lives in `dotfiles_hyprland/packages/base.txt`.
Launch **Telegram Desktop** from Rofi, sign in with your existing Telegram
account, then open [Jackshome_bot](https://t.me/Jackshome_bot).

The packaged desktop entry supplies launcher and `tg://` integration. Settings
and authenticated session data stay local in `~/.local/share/TelegramDesktop/`;
this directory is excluded from Git in the dotfiles repository.
