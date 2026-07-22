#!/bin/sh
set -eu
. "$INSTALL_ROOT/resources.sh"

job_field() {
    index=$1
    field=$2
    case "$index:$field" in
        0:user) printf backup ;; 0:command) printf rotate-reports ;; 0:exit) printf 23 ;;
        0:detail) printf 'destination filesystem is full' ;;
        1:user) printf inventory ;; 1:command) printf sync-assets ;; 1:exit) printf 127 ;;
        1:detail) printf 'sync-assets-helper: not found' ;;
        2:user) printf reports ;; 2:command) printf publish-digest ;; 2:exit) printf 6 ;;
        2:detail) printf 'could not resolve reports.example.net' ;;
        3:user) printf metrics ;; 3:command) printf export-summary ;; 3:exit) printf 64 ;;
        3:detail) printf 'METRICS_DESTINATION is not set' ;;
        4:user) printf archive ;; 4:command) printf copy-ledger ;; 4:exit) printf 13 ;;
        4:detail) printf 'permission denied opening /srv/archive/ledger' ;;
        *) die "unknown job field: $index:$field" ;;
    esac
}

fresh_case
host=$(hostname_for backup)
profile_hex=$(derive_hex profile)
profile=$(( $(hex_byte "$profile_hex" 0) % 5 ))
profile_id=$(profile_field "$profile" id)
case "$(profile_field "$profile" auth)" in
    auth.log) cron_name=syslog ;;
    *) cron_name=cron ;;
esac
mkdir -p "$CASE_DIR/hosts/$host/var/log/jobs"
cron_log="$CASE_DIR/hosts/$host/var/log/$cron_name"
: > "$cron_log"
target=$(( $(hex_byte "$(derive_hex target)" 0) % 5 ))
case_id="CRON-$(range_from_byte "$(hex_byte "$(derive_hex answer)" 0)" 1000 9999)"

i=0
while [ "$i" -lt 5 ]; do
    user=$(job_field "$i" user)
    command=$(job_field "$i" command)
    status=$(job_field "$i" exit)
    detail=$(job_field "$i" detail)
    event_time=$(syslog_time "job-$i" 0)
    run_id="RUN-$(hex_fragment "job-run-$i" 8)"
    if [ "$i" -eq "$target" ]; then
        run_id=$case_id
        target_user=$user
        target_command=$command
        target_exit=$status
    fi
    printf '%s %s CRON[%d]: (%s) CMD (/usr/local/sbin/%s --run-id %s)\n' \
        "$event_time" "$host" "$((3100 + i))" "$user" "$command" "$run_id" >> "$cron_log"
    {
        printf 'RUN_ID=%s\n' "$run_id"
        printf 'COMMAND=%s\n' "$command"
        printf 'USER=%s\n' "$user"
        printf 'MESSAGE=%s\n' "$detail"
        printf 'EXIT_STATUS=%s\n' "$status"
    } > "$CASE_DIR/hosts/$host/var/log/jobs/$run_id.log"
    i=$((i + 1))
done

# A successful rerun is plausible noise and must not replace the requested run.
printf '%s %s CRON[3999]: (%s) CMD (/usr/local/sbin/%s --run-id RUN-retry-ok)\n' \
    "$(syslog_time layout 0)" "$host" "$target_user" "$target_command" >> "$cron_log"
printf 'RUN_ID=RUN-retry-ok\nCOMMAND=%s\nUSER=%s\nMESSAGE=completed\nEXIT_STATUS=0\n' \
    "$target_command" "$target_user" > "$CASE_DIR/hosts/$host/var/log/jobs/RUN-retry-ok.log"

{
    echo "SCHEDULED_JOB_CASE"
    echo "TARGET_HOST=$host"
    echo "TARGET_RUN_ID=$case_id"
    echo "REMOTE_LOG_STYLE=$profile_id"
    echo "Correlate the CRON record with the job output carrying the same run ID."
} > "$CASE_DIR/CASE.txt"

answer="$target_user|$target_command|$target_exit"
write_readme "Investigate the scheduled run identified in evidence/CASE.txt. Correlate the distro-appropriate cron log with the matching file under var/log/jobs. Submit: username|command-name|exit-status"
record_answer "$answer"
finish_level

