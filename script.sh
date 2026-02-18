#!/usr/bin/env bash

set -euo pipefail

# Required commands for this script
REQUIRED_CMDS=(
    find
    sha256sum
    awk
    printf
    sort
    git
    rm
    mkdir
)

for cmd in "${REQUIRED_CMDS[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Error: required command '$cmd' is not installed or not in PATH."
        exit 1
    fi
done

UNIT_DIRS=(
    /etc/systemd/system
    /usr/lib/systemd/system
    /lib/systemd/system
    /usr/local/lib/systemd/system
    /run/systemd/system
)

CRON_DIRS=(
    /etc/crontab
    /etc/cron.hourly
    /etc/cron.daily
    /etc/cron.weekly
    /etc/cron.monthly
    /etc/cron.d
    /var/spool/cron
    /var/spool/cron/crontabs
    /etc/anacrontab
)

hash_units() {
    local out_file="$1"
    : > "$out_file"

    for dir in "${UNIT_DIRS[@]}"; do
        if [[ -d "$dir" ]]; then
            find "$dir" -type f \( -name "*.timer" -o -name "*.service" \) \
                -exec sh -c 'for f; do
                    hash=$(sha256sum "$f" | awk "{print \$1}")
                    printf "%s\t\t\t%s\n" "$f" "$hash"
                done' _ {} + >> "$out_file"
        fi
    done

    # Hash cron paths
    for path in "${CRON_PATHS[@]}"; do
        if [[ -f "$path" ]]; then
            # Single file
            hash=$(sha256sum "$path" | awk '{print $1}')
            printf "%s\t%s\n" "$path" "$hash" >> "$out_file"
        elif [[ -d "$path" ]]; then
            # Directory of cron jobs
            find "$path" -type f -exec sh -c '
                for f; do
                    hash=$(sha256sum "$f" | awk "{print \$1}")
                    printf "%s\t%s\n" "$f" "$hash"
                done
            ' _ {} + >> "$out_file"
        fi
    done

    sort -o "$out_file" "$out_file"
}

echo "Building snapshot"

# Build current snapshot
hash_units "./units.sha256"
echo "Remember to clear this repo from your machine"
