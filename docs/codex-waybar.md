# Codex allowance in Waybar

The laptop and docked bars show Codex's **remaining** allowance beside
OpenRouter, with an OpenAI icon followed by the percentage (for example `95%`
for a weekly-only allowance). The icon is bundled from the OpenAI IDE extension.
Both usage widgets share one CSS rule for 14px icons, spacing, and status colors;
their SVGs use the same Nord foreground color.
Only windows actually returned by OpenAI appear; when multiple windows are
available, `5h` and `W` labels distinguish them. Hover identifies each window.

The module refreshes once when Waybar starts and on clicks, with no periodic
polling. Both the OpenAI and OpenRouter widgets use the same clicks in laptop
and docked layouts: left-click refreshes and opens the corresponding website
(Codex usage dashboard or OpenRouter logs); right-click refreshes only.
Codex uses Waybar signal 10 (`pkill -x -RTMIN+10 waybar`); OpenRouter uses signal 9.
Each invocation fetches fresh account data, without a cache-age delay.

Hover shows remaining allowance, reset countdown/date, last refresh time, and
`Available: X%/day`: weekly percentage remaining divided by the fractional days
until reset. This line turns red below 14%/day and is omitted when weekly data is
missing or stale. No daily usage tracking is stored. Values and countdowns stay
unchanged until the next
refresh. Data comes from the authenticated Codex app server's
[`account/rateLimits/read`](https://learn.chatgpt.com/docs/app-server#6-rate-limits-chatgpt)
method. Windows are identified by reported duration, not primary/secondary
position. No model turns are started, and API billing keys are not used.

Below 25% remaining the text turns amber; below 10% it turns red. Desktop alerts
fire once per threshold per reset window, including after restarting the bar.
Alerts are evaluated only when refreshing. A failed refresh preserves the last
values in gray with `⟳` and a stale tooltip. If a refresh returns a window whose
reset time has already passed, its values are also marked stale.

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
