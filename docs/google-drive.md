# Google Drive Mount

Google Drive is mounted at `~/GoogleDrive` with `rclone mount` as a user systemd service.

The service uses a long directory cache plus Google Drive change polling so browsing stays fast without repeatedly refetching folder listings. File reads use the rclone VFS cache in `~/.cache/rclone`, capped at 50 GB.

Tracked config:

- `system/systemd-user/rclone-googledrive.service`
- `system/user-services.txt`

Operational commands:

```bash
systemctl --user status rclone-googledrive.service
systemctl --user restart rclone-googledrive.service
journalctl --user -u rclone-googledrive.service
```
