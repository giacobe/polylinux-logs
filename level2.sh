#!/bin/sh
set -eu
. "$INSTALL_ROOT/resources.sh"

fresh_case
host=$(hostname_for application)
mkdir -p "$CASE_DIR/hosts/$host/collected"
answer_hex=$(derive_hex answer)
previous=$((2 + $(hex_byte "$answer_hex" 0) % 5))
boot_id=$(hex_fragment boot-current 32)
start="$(iso_time timestamp 0)"

{
    echo "# Captured output: journalctl --list-boots --no-pager"
    n=$previous
    while [ "$n" -gt 0 ]; do
        old_id=$(hex_fragment "boot-old-$n" 32)
        old_hour=$(( (3 + n * 3 + $(hex_byte "$answer_hex" "$n")) % 24 ))
        printf '%3d %s %sT%02d:%02d:00-04:00--%sT%02d:%02d:00-04:00\n' \
            "-$n" "$old_id" "$currentDate" "$old_hour" "$((n * 7 % 60))" \
            "$currentDate" "$(( (old_hour + 2) % 24 ))" "$((n * 11 % 60))"
        n=$((n - 1))
    done
    printf '  0 %s %s-04:00--running\n' "$boot_id" "$start"
} > "$CASE_DIR/hosts/$host/collected/journal-list-boots.txt"

{
    echo "# Captured output: journalctl -b -o short-iso --no-pager"
    printf '%s-04:00 %s kernel: Linux version %s\n' "$start" "$host" "$(profile_field 0 kernel)"
    printf '%s-04:00 %s systemd[1]: systemd 255.4 running in system mode\n' "$(iso_time layout 3)" "$host"
    printf '%s-04:00 %s systemd[1]: Reached target Multi-User System.\n' "$(iso_time layout 6)" "$host"
} > "$CASE_DIR/hosts/$host/collected/journal-current-boot.log"

{
    echo "BOOT_HISTORY_CASE"
    echo "TARGET_HOST=$host"
    echo "Use the row whose boot offset is 0."
} > "$CASE_DIR/CASE.txt"

answer="$boot_id|$start|$previous"
write_readme "Inspect the captured boot history for the host named in evidence/CASE.txt. Report the current boot ID, its ISO start time without the UTC offset, and the number of previous boots represented. Submit: boot-id|YYYY-MM-DDTHH:MM:SS|previous-count"
record_answer "$answer"
finish_level

