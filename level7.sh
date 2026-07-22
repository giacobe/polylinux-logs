#!/bin/sh
set -eu
. "$INSTALL_ROOT/resources.sh"

package_field() {
    index=$1
    field=$2
    case "$index:$field" in
        0:operation) printf upgrade ;; 0:name) printf telemetry-agent ;;
        0:old) printf 3.4.1-1 ;; 0:new) printf 3.4.2-1 ;;
        1:operation) printf install ;; 1:name) printf report-renderer ;;
        1:old) printf none ;; 1:new) printf 2.8.0-3 ;;
        2:operation) printf remove ;; 2:name) printf legacy-exporter ;;
        2:old) printf 1.9.7-2 ;; 2:new) printf none ;;
        3:operation) printf downgrade ;; 3:name) printf gateway-policy ;;
        3:old) printf 5.2.1-4 ;; 3:new) printf 5.1.9-8 ;;
        *) die "unknown package field: $index:$field" ;;
    esac
}

fresh_case
host=$(hostname_for application)
profile=$(( $(hex_byte "$(derive_hex profile)" 0) % 5 ))
manager=$(profile_field "$profile" package)
target=$(( $(hex_byte "$(derive_hex target)" 0) % 4 ))
operation=$(package_field "$target" operation)
package=$(package_field "$target" name)
old=$(package_field "$target" old)
new=$(package_field "$target" new)
transaction="TX-$(hex_fragment transaction 10)"
event_time=$(iso_time timestamp 0)

mkdir -p "$CASE_DIR/hosts/$host/var/log"
if [ "$manager" = apt ]; then
    mkdir -p "$CASE_DIR/hosts/$host/var/log/apt"
    history="$CASE_DIR/hosts/$host/var/log/apt/history.log"
    dpkg="$CASE_DIR/hosts/$host/var/log/dpkg.log"
    {
        echo "Start-Date: $event_time"
        echo "Commandline: apt-get --assume-yes $operation $package"
        echo "Requested-By: maintainer (1001)"
        case "$operation" in
            install) echo "Install: $package:amd64 ($new)" ;;
            remove) echo "Remove: $package:amd64 ($old)" ;;
            *) echo "Upgrade: $package:amd64 ($old, $new)" ;;
        esac
        echo "Transaction-ID: $transaction"
        echo "End-Date: $event_time"
        echo
        echo "Start-Date: $(iso_time noise 0)"
        echo "Commandline: unattended-upgrade"
        echo "Upgrade: ca-certificates:all (20250419, 20230311)"
        echo "Transaction-ID: TX-routine"
        echo "End-Date: $(iso_time noise 3)"
    } > "$history"
    case "$operation" in
        install) printf '%s status installed %s:amd64 %s\n' "$event_time" "$package" "$new" ;;
        remove) printf '%s status not-installed %s:amd64 %s\n' "$event_time" "$package" "$old" ;;
        *) printf '%s upgrade %s:amd64 %s %s\n' "$event_time" "$package" "$old" "$new" ;;
    esac > "$dpkg"
else
    dnf="$CASE_DIR/hosts/$host/var/log/dnf.log"
    rpm="$CASE_DIR/hosts/$host/var/log/dnf.rpm.log"
    {
        printf '%s INFO --- logging initialized ---\n' "$event_time"
        printf '%s DDEBUG Command: dnf -y %s %s\n' "$event_time" "$operation" "$package"
        printf '%s INFO Transaction ID: %s\n' "$event_time" "$transaction"
        printf '%s INFO Completed transaction\n' "$event_time"
        printf '%s INFO Transaction ID: TX-routine\n' "$(iso_time noise 0)"
    } > "$dnf"
    case "$operation" in
        install) printf '%s INFO Installed: %s-%s.x86_64\n' "$event_time" "$package" "$new" ;;
        remove) printf '%s INFO Removed: %s-%s.x86_64\n' "$event_time" "$package" "$old" ;;
        *) printf '%s INFO %s: %s-%s.x86_64 -> %s-%s.x86_64\n' "$event_time" "$operation" "$package" "$old" "$package" "$new" ;;
    esac > "$rpm"
fi

{
    echo "PACKAGE_CHANGE_CASE"
    echo "TARGET_HOST=$host"
    echo "TRANSACTION_ID=$transaction"
    echo "PACKAGE_MANAGER=$manager"
    echo "Use 'none' for the missing side of an install or removal."
} > "$CASE_DIR/CASE.txt"

answer="$operation|$package|$old|$new"
write_readme "Inspect the package logs for the transaction in evidence/CASE.txt. Determine the operation, package, old version, and new version. Use none where no old or new version exists. Submit: operation|package|old-version|new-version"
record_answer "$answer"
finish_level
