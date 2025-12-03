#!/bin/bash
START_TIME=$(date +%s)

###########################################
# LOAD CONFIG FROM DOCKER ENV VARIABLES
###########################################

DISCORD_WEBHOOK="${DISCORD_WEBHOOK}"

# Comma-separated list of sources
IFS=',' read -ra SOURCES <<< "$SOURCE_PATHS"

# Comma-separated cloud destinations
IFS=',' read -ra CLOUD_DESTS <<< "$CLOUD_DESTS"

# Comma-separated exclusions
IFS=',' read -ra EXCLUDES <<< "$EXCLUDES"

DEST="${DEST_PATH}"
MIN_FREE_GB="${MIN_FREE_GB:-10}"
KEEP_LOCAL="${KEEP_LOCAL:-7}"

###########################################
# HELPERS
###########################################

discord() {
    [[ -z "$DISCORD_WEBHOOK" ]] && return

    curl -s -X POST \
         -H "Content-Type: application/json" \
         -d "{\"content\": \"$1\"}" \
         "$DISCORD_WEBHOOK" >/dev/null
}

run_rclone() {
    rclone "$@" --progress --stats=20s
}

###########################################
# START
###########################################

discord ":arrow_up: Backup Started"
echo "Backup started."

###########################################
# LOCAL STORAGE CHECK
###########################################

LOCAL_FREE_KB=$(df --output=avail "$DEST" | tail -1)
LOCAL_FREE_GB=$(( LOCAL_FREE_KB / 1024 / 1024 ))

if (( LOCAL_FREE_GB < MIN_FREE_GB )); then
    discord ":x: Not enough local storage (${LOCAL_FREE_GB}GB free; required ${MIN_FREE_GB}GB)"
    echo "ERROR: Not enough local storage."
    exit 1
fi

###########################################
# CREATE TIMESTAMP DIRECTORY
###########################################

TS=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_DIR="${DEST}/${TS}"
mkdir -p "$BACKUP_DIR"

###########################################
# LOCAL BACKUP
###########################################

EXCLUDE_ARGS=()
for EX in "${EXCLUDES[@]}"; do
    [[ -n "$EX" ]] && EXCLUDE_ARGS+=( --exclude "$EX" )
done

for SRC in "${SOURCES[@]}"; do
    [[ -z "$SRC" ]] && continue
    NAME=$(basename "$SRC")

    echo "Copying $SRC → $BACKUP_DIR/$NAME"

    if ! run_rclone copy "$SRC" "$BACKUP_DIR/$NAME" \
         --create-empty-src-dirs \
         "${EXCLUDE_ARGS[@]}"; then
        discord ":x: Local backup FAILED for \`$SRC\`"
        echo "ERROR: Local backup failed for $SRC"
        exit 1
    fi
done

discord ":white_check_mark: Local backup complete"
echo "Local backup complete."

###########################################
# DELETE OLD LOCAL BACKUPS
###########################################

COUNT=$(ls -1 "$DEST" | wc -l || echo 0)

if (( COUNT > KEEP_LOCAL )); then
    echo "Deleting old backups (keeping last $KEEP_LOCAL)..."
    ls -1 "$DEST" | sort | head -n -"$KEEP_LOCAL" | while read -r OLD; do
        [[ -z "$OLD" ]] && continue
        rm -rf "$DEST/$OLD"
    done
    discord ":broom: Old backups cleaned (kept last ${KEEP_LOCAL})."
fi

###########################################
# CLOUD SYNC (PARALLEL)
###########################################

discord ":cloud: Starting cloud sync..."
echo "Starting cloud sync..."

declare -a PIDS

for CLOUD in "${CLOUD_DESTS[@]}"; do
    [[ -z "$CLOUD" ]] && continue

    (
        if run_rclone sync "$DEST" "$CLOUD"; then
            discord ":white_sun_cloud: Cloud sync completed → \`$CLOUD\`"
            echo "Cloud sync OK → $CLOUD"
        else
            discord ":x: Cloud sync FAILED → \`$CLOUD\`"
            echo "Cloud sync FAILED → $CLOUD"
            exit 1
        fi
    ) &

    PIDS+=($!)
done

FAIL=false
for PID in "${PIDS[@]}"; do
    wait "$PID" || FAIL=true
done

if $FAIL; then
    discord ":warning: One or more cloud syncs FAILED."
    echo "Some cloud syncs failed."
else
    discord ":white_check_mark: All cloud syncs successful."
    echo "All cloud syncs successful."
fi

###########################################
# WRAP UP
###########################################

END=$(date +%s)
ELAPSED=$((END - START_TIME))

ELAPSED_HMS=$(printf '%02d:%02d:%02d' \
    $((ELAPSED/3600)) \
    $(((ELAPSED%3600)/60)) \
    $((ELAPSED%60)))

discord ":tada: Backup Finished — ${ELAPSED_HMS}"
echo "Backup done in ${ELAPSED_HMS}."

exit 0
