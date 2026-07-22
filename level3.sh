#!/bin/sh
set -eu
. "$INSTALL_ROOT/resources.sh"

service_field() {
    index=$1
    field=$2
    case "$index:$field" in
        0:unit) printf backup-agent.service ;; 0:cause) printf permission-denied ;;
        0:detail) printf 'open /srv/backups/nightly.tar: Permission denied' ;;
        0:status) printf 13 ;;
        1:unit) printf inventory-sync.service ;; 1:cause) printf configuration-missing ;;
        1:detail) printf 'configuration file /etc/inventory-sync.conf not found' ;;
        1:status) printf 2 ;;
        2:unit) printf metrics-exporter.service ;; 2:cause) printf port-in-use ;;
        2:detail) printf 'listen tcp 0.0.0.0:9100: bind: Address already in use' ;;
        2:status) printf 98 ;;
        3:unit) printf report-worker.service ;; 3:cause) printf environment-missing ;;
        3:detail) printf 'required environment variable REPORT_QUEUE is not set' ;;
        3:status) printf 64 ;;
        4:unit) printf remote-mount.service ;; 4:cause) printf dependency-timeout ;;
        4:detail) printf 'dependency dev-disk-by\\x2duuid.mount timed out' ;;
        4:status) printf 110 ;;
        *) die "unknown service field: $index:$field" ;;
    esac
}

fresh_case
host=$(hostname_for application)
mkdir -p "$CASE_DIR/hosts/$host/units"
target_hex=$(derive_hex target)
target=$(( $(hex_byte "$target_hex" 0) % 5 ))
target_time=$(iso_time timestamp 0)

i=0
while [ "$i" -lt 5 ]; do
    unit=$(service_field "$i" unit)
    cause=$(service_field "$i" cause)
    detail=$(service_field "$i" detail)
    status=$(service_field "$i" status)
    event_time=$(iso_time "noise-$i" 0)
    state="recovered"
    [ "$i" -ne "$target" ] || { event_time=$target_time; state="unresolved"; }
    {
        echo "# Captured output: journalctl -u $unit -o short-iso --no-pager"
        printf '%s-04:00 %s systemd[1]: Starting %s...\n' "$event_time" "$host" "$unit"
        printf '%s-04:00 %s %s[1427]: ERROR: %s\n' "$event_time" "$host" "$unit" "$detail"
        printf '%s-04:00 %s systemd[1]: %s: Main process exited, code=exited, status=%s\n' "$event_time" "$host" "$unit" "$status"
        printf '%s-04:00 %s systemd[1]: Failed to start %s.\n' "$event_time" "$host" "$unit"
        printf 'CASE_STATE=%s\n' "$state"
        printf 'CAUSE_CODE=%s\n' "$cause"
    } > "$CASE_DIR/hosts/$host/units/$unit.log"
    i=$((i + 1))
done

target_unit=$(service_field "$target" unit)
target_cause=$(service_field "$target" cause)
{
    echo "SERVICE_FAILURE_CASE"
    echo "TARGET_HOST=$host"
    echo "Investigate the one unit whose CASE_STATE remains unresolved."
    echo "Submit its explicit CAUSE_CODE, not systemd's generic result."
} > "$CASE_DIR/CASE.txt"

answer="$target_unit|$target_cause|$target_time"
write_readme "Read evidence/CASE.txt and the captured unit logs. Identify the unresolved service, its explicit CAUSE_CODE, and the ISO failure time without an offset. Submit: unit-name|cause-code|YYYY-MM-DDTHH:MM:SS"
record_answer "$answer"
finish_level

