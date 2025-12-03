# Unraid Backup Tool

A fully containerized, GitOps-friendly backup tool for Unraid.

- Multi-source backup (via `SOURCE_PATHS`)
- Local timestamped backups with retention
- Parallel rclone cloud sync
- Discord notifications
- No Unraid plugins required (rclone, jq, curl are built into the image)
- Semantic versioning + automated Docker image builds

## 🚀 Running on Unraid

### 1. Deploy the Container

- Use the provided Unraid XML (`unraid/unraid-backup-tool.xml`), or
- Add the container manually with this image:

```text
uninspiredenvy/unraid-backup-tool:latest
```

Mount these default paths:

- `/config` → `/mnt/user/appdata/unraid-backup-tool`
- `/source` → `/mnt/user/appdata/Plex-Media-Server`
- `/dest` → `/mnt/user/backups/Cyberdyne/Plex`

### 2. Environment Variables

- `DISCORD_WEBHOOK` – Discord webhook URL (optional but recommended)
- `SOURCE_PATHS` – Comma-separated list of source paths inside the container (e.g. `/source` or `/source1,/source2`)
- `DEST_PATH` – Local backup root inside the container (default `/dest`)
- `CLOUD_DESTS` – Comma-separated rclone cloud destinations (e.g. `google:unraidbackup/plex,onedrive:Backups/unraid`)
- `EXCLUDES` – Comma-separated rclone exclude patterns (e.g. `Media/**,Cache/**,Metadata/**`)
- `MIN_FREE_GB` – Minimum free space required at DEST_PATH (default: `10`)
- `KEEP_LOCAL` – Number of local timestamped backups to retain (default: `7`)
- `TZ` – Timezone (e.g. `America/Chicago`)

### 3. Rclone Setup

This image expects your `rclone.conf` to live at:

```text
/mnt/user/appdata/unraid-backup-tool/rclone.conf
```

On Unraid, generate it via:

```bash
rclone config
```

And copy it into that path.

See rclone docs for provider-specific setup:  
https://rclone.org/docs/

### 4. Scheduling

This container is designed to:

- Run a single backup when started
- Exit when finished

Use **Unraid’s Docker scheduler**:

1. Go to **Docker** tab  
2. Click the container → **Edit**  
3. Use the built-in scheduler to set a cron expression, e.g.:

```text
0 3 * * *
```

to run every day at 3AM.

## 🛠 Development

Build locally:

```bash
docker build -t uninspiredenvy/unraid-backup-tool:dev .
```

Run locally:

```bash
docker run --rm \
  -e SOURCE_PATHS="/source" \
  -e DEST_PATH="/dest" \
  -e CLOUD_DESTS="google:unraidbackup/plex" \
  -v /path/to/source:/source \
  -v /path/to/dest:/dest \
  uninspiredenvy/unraid-backup-tool:dev
```

## 🔁 CI/CD & Semantic Versioning

- `version.txt` tracks the current version.
- GitHub Actions (`.github/workflows/release.yml`) bumps the version based on commit messages:
  - `fix:` → patch
  - `feat:` → minor
  - `BREAKING CHANGE:` → major
- Builds and pushes Docker images:
  - `uninspiredenvy/unraid-backup-tool:x.y.z`
  - `uninspiredenvy/unraid-backup-tool:latest`
- Generates `CHANGELOG.md` from commits.

You must set the following GitHub repository secrets:

- `DOCKERHUB_USERNAME`
- `DOCKERHUB_TOKEN`

## 🧾 License

Add your preferred license here (MIT, Apache-2.0, etc.).
