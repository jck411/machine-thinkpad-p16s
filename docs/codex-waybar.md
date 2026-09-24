# Codex allowance in Waybar

The laptop and docked bars show Codex's **remaining** 5-hour (`5h`) and weekly
(`W`) allowance beside OpenRouter. Hover for reset countdowns, local reset dates,
and the last successful refresh; click to open the Codex usage dashboard.

The module polls every 120 seconds through the authenticated Codex app server's
[`account/rateLimits/read`](https://learn.chatgpt.com/docs/app-server#6-rate-limits-chatgpt)
method. Windows are identified by their reported duration, not primary/secondary
position. A window omitted by OpenAI displays `—`; it does not mean 100% remains.
The Pro account currently returns only the weekly window. No model turns are
started, and API billing keys are not used.

Below 25% remaining the text turns amber; below 10% it turns red. Desktop alerts
fire once per threshold per reset window, including after restarting the bar.
Polling alerts require Waybar to be running. A failed refresh preserves the last
values in gray with `⟳` and a stale tooltip. Passing a reset time also marks the
values stale until a successful fetch supplies a new window.

## Dependencies and state

The implementation and both layouts belong to
[`dotfiles_hyprland/config/waybar`](../../dotfiles_hyprland/config/waybar/).
It uses the existing `~/.local/bin/uv`, Python's standard library, `notify-send`
(libnotify), and the signed-in Codex CLI. It finds `codex` on PATH or the newest
bundled executable in the local stable/Insiders OpenAI VS Code extensions.
No new service, Python dependency, or credential copy is required.

`state/codex-usage.json` caches only allowance windows, refresh time, and alert
thresholds; `state/codex-usage.lock` coordinates concurrent bar instances.
Both are already Git-ignored. Authentication remains managed by Codex.

## Validation and recovery

```bash
~/.local/bin/uv run --offline --no-project python ~/.config/waybar/codex-usage.py
cd ~/REPOS/dotfiles_hyprland
uv run --offline --no-project python -m unittest discover -s tests -p 'test_codex_usage.py'
./sync.sh status
```

If data is unavailable, check Codex sign-in and the CLI/extension installation.
Use `SUPER+B` to reload the bar after configuration changes. To remove the
widget, remove `custom/codex` from both layouts' `modules-right` arrays and reload.
