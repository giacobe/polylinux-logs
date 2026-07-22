#!/bin/sh
set -eu

ANSWER_DIR=${ANSWER_DIR:-/var/lib/system-logs/answers}
CASE_ROOT=${CASE_ROOT:-/srv/log-collector/cases}
failures=0

check() {
    level=$1
    actual=$2
    expected=$(sed -n '1p' "$ANSWER_DIR/level$level")
    if [ "$actual" = "$expected" ]; then
        echo "level$level: PASS"
    else
        echo "level$level: FAIL" >&2
        echo "  expected: $expected" >&2
        echo "  solver:   $actual" >&2
        failures=$((failures + 1))
    fi
}

# Level 1: follow the asset assignment into the matching current inventory.
asset=$(sed -n 's/^TARGET_ASSET=//p' "$CASE_ROOT/level1/ASSIGNMENT.txt")
inventory=$(grep -rl "^ASSET=$asset$" "$CASE_ROOT/level1/inventory" | head -n 1)
host_dir=$(dirname "$inventory")
host=$(sed -n 's/^HOSTNAME=//p' "$inventory")
distro=$(sed -n 's/^DISTRIBUTION_LABEL=//p' "$inventory")
kernel=$(awk '{print $3}' "$host_dir/uname.txt")
arch=$(awk '{print $(NF-1)}' "$host_dir/uname.txt")
check 1 "$host|$distro|$kernel|$arch"

# Level 2: select offset 0 and count the negative boot rows.
boots="$CASE_ROOT/level2/hosts"/*/collected/journal-list-boots.txt
current=$(awk '$1 == 0 {print $2 "|" $3}' $boots)
current_id=$(printf '%s' "$current" | cut -d '|' -f 1)
current_start=$(printf '%s' "$current" | cut -d '|' -f 2 | sed 's/-04:00--running$//')
previous=$(awk '$1 ~ /^-[0-9]+$/ {count++} END {print count+0}' $boots)
check 2 "$current_id|$current_start|$previous"

# Level 3: locate the only unresolved unit and parse its own evidence.
unit_log=$(grep -rl '^CASE_STATE=unresolved$' "$CASE_ROOT/level3/hosts")
unit=$(basename "$unit_log" .log)
cause=$(sed -n 's/^CAUSE_CODE=//p' "$unit_log")
failed_at=$(awk '!/^#/ && /Starting/ {print $1; exit}' "$unit_log" | sed 's/-04:00$//')
check 3 "$unit|$cause|$failed_at"

# Level 4: count only the authoritative Failed password record type.
source_ip=$(sed -n 's/^TARGET_SOURCE=//p' "$CASE_ROOT/level4/CASE.txt")
auth_log=$(find "$CASE_ROOT/level4/hosts" -type f \( -name auth.log -o -name secure \))
matching=$(grep "Failed password for invalid user .* from $source_ip " "$auth_log")
auth_user=$(printf '%s\n' "$matching" | sed -n '1s/.*invalid user \([^ ]*\) from.*/\1/p')
auth_count=$(printf '%s\n' "$matching" | wc -l | tr -d ' ')
check 4 "$auth_user|$source_ip|$auth_count"

# Level 5: correlate the session ID in the normalized last capture.
session=$(sed -n 's/^TARGET_SESSION_ID=//p' "$CASE_ROOT/level5/CASE.txt")
last_file=$(find "$CASE_ROOT/level5/hosts" -name last-Fai.txt)
login_answer=$(awk -v session="$session" '$7 == session {print $1 "|" $3 "|" $6}' "$last_file")
check 5 "$login_answer"

# Level 6: correlate cron's run ID with its job output.
run=$(sed -n 's/^TARGET_RUN_ID=//p' "$CASE_ROOT/level6/CASE.txt")
job_file=$(grep -rl "^RUN_ID=$run$" "$CASE_ROOT/level6/hosts")
job_user=$(sed -n 's/^USER=//p' "$job_file")
job_command=$(sed -n 's/^COMMAND=//p' "$job_file")
job_status=$(sed -n 's/^EXIT_STATUS=//p' "$job_file")
check 6 "$job_user|$job_command|$job_status"

# Level 7: parse the selected package-manager transaction and companion log.
manager=$(sed -n 's/^PACKAGE_MANAGER=//p' "$CASE_ROOT/level7/CASE.txt")
transaction=$(sed -n 's/^TRANSACTION_ID=//p' "$CASE_ROOT/level7/CASE.txt")
if [ "$manager" = apt ]; then
    history=$(find "$CASE_ROOT/level7/hosts" -path '*/apt/history.log')
    command_line=$(awk -v tx="$transaction" '
        /^Commandline:/ {command=$0}
        /^Transaction-ID:/ && $2 == tx {print command}
    ' "$history")
    operation=$(printf '%s\n' "$command_line" | awk '{print $(NF-1)}')
    package=$(printf '%s\n' "$command_line" | awk '{print $NF}')
    detail=$(grep "$package:amd64" "$(dirname "$(dirname "$history")")/dpkg.log")
    case "$operation" in
        install) old=none; new=$(printf '%s\n' "$detail" | awk '{print $NF}') ;;
        remove) old=$(printf '%s\n' "$detail" | awk '{print $NF}'); new=none ;;
        *) old=$(printf '%s\n' "$detail" | awk '{print $(NF-1)}'); new=$(printf '%s\n' "$detail" | awk '{print $NF}') ;;
    esac
else
    dnf=$(find "$CASE_ROOT/level7/hosts" -name dnf.log)
    command_line=$(grep 'DDEBUG Command:' "$dnf")
    operation=$(printf '%s\n' "$command_line" | awk '{print $(NF-1)}')
    package=$(printf '%s\n' "$command_line" | awk '{print $NF}')
    rpm=$(find "$CASE_ROOT/level7/hosts" -name dnf.rpm.log)
    detail=$(grep "$package" "$rpm")
    case "$operation" in
        install) old=none; new=$(printf '%s\n' "$detail" | sed "s/.*$package-//; s/\.x86_64$//") ;;
        remove) old=$(printf '%s\n' "$detail" | sed "s/.*$package-//; s/\.x86_64$//"); new=none ;;
        *)
            old=$(printf '%s\n' "$detail" | sed "s/^.*$operation: $package-//; s/\.x86_64 ->.*//")
            new=$(printf '%s\n' "$detail" | sed "s/.* -> $package-//; s/\.x86_64$//") ;;
    esac
fi
check 7 "$operation|$package|$old|$new"

# Level 8: find the target access record, then join on request_id.
target_path=$(sed -n 's/^TARGET_PATH=//p' "$CASE_ROOT/level8/CASE.txt")
access=$(find "$CASE_ROOT/level8/hosts" -name access.log)
access_record=$(grep "\"POST $target_path HTTP/1.1\"" "$access")
web_ip=$(printf '%s\n' "$access_record" | awk '{print $1}')
web_status=$(printf '%s\n' "$access_record" | awk '{print $9}')
request=$(printf '%s\n' "$access_record" | sed 's/.*request_id=//')
app=$(find "$CASE_ROOT/level8/hosts" -name application.jsonl)
app_record=$(grep "\"request_id\":\"$request\"" "$app")
error=$(printf '%s\n' "$app_record" | sed 's/.*"error_code":"\([^"]*\)".*/\1/')
check 8 "$web_ip|$request|$web_status|$error"

# Level 9: interpret the target timestamp's event bundle.
kernel_time=$(sed -n 's/^EVENT_TIME=//p' "$CASE_ROOT/level9/CASE.txt")
kernel_log=$(find "$CASE_ROOT/level9/hosts" -name kernel.log)
bundle=$(grep "^$kernel_time " "$kernel_log")
if printf '%s\n' "$bundle" | grep -q 'I/O error'; then
    subject=$(printf '%s\n' "$bundle" | sed -n 's/.*I\/O error, dev \([^,]*\),.*/\1/p' | head -n 1)
    incident=io-error; consequence=filesystem-read-only
elif printf '%s\n' "$bundle" | grep -q 'Out of memory'; then
    subject=$(printf '%s\n' "$bundle" | sed -n 's/.*Killed process [0-9]* (\([^)]*\)).*/\1/p')
    incident=oom-kill; consequence=service-restarted
elif printf '%s\n' "$bundle" | grep -q 'NIC Link is Down'; then
    subject=$(printf '%s\n' "$bundle" | sed -n 's/.*e1000: \([^ ]*\) NIC Link is Down.*/\1/p')
    incident=link-flap; consequence=connection-restored
elif printf '%s\n' "$bundle" | grep -q 'temperature above threshold'; then
    subject=cpu0; incident=thermal-throttle; consequence=frequency-limited
else
    subject=usb-2-1; incident=device-reset; consequence=device-reenumerated
fi
check 9 "$subject|$incident|$consequence"

# Level 10: solve from the compressed normalized aggregate timeline.
case_id=$(sed -n 's/^CASE_ID=//p' "$CASE_ROOT/level10/CASE.txt")
timeline=$(find "$CASE_ROOT/level10/aggregate" -name '*.gz')
root_record=$(gzip -dc "$timeline" | grep "case=$case_id event=root-change")
failure_record=$(gzip -dc "$timeline" | grep "case=$case_id event=service-failure")
external_record=$(gzip -dc "$timeline" | grep "case=$case_id event=external-failure")
root_code=$(printf '%s\n' "$root_record" | sed 's/.* code=\([^ ]*\).*/\1/')
service=$(printf '%s\n' "$failure_record" | sed 's/.* service=\([^ ]*\).*/\1/')
first_failure=$(printf '%s\n' "$external_record" | awk '{print $1}')
check 10 "$root_code|$service|$first_failure"

if [ "$failures" -ne 0 ]; then
    echo "$failures level(s) failed validation." >&2
    exit 1
fi
echo "All levels passed."
