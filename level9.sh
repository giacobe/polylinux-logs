#!/bin/sh
set -eu
. "$INSTALL_ROOT/resources.sh"

kernel_field() {
    index=$1
    field=$2
    case "$index:$field" in
        0:subject) printf sdb ;; 0:incident) printf io-error ;; 0:consequence) printf filesystem-read-only ;;
        1:subject) printf report-worker ;; 1:incident) printf oom-kill ;; 1:consequence) printf service-restarted ;;
        2:subject) printf eth1 ;; 2:incident) printf link-flap ;; 2:consequence) printf connection-restored ;;
        3:subject) printf cpu0 ;; 3:incident) printf thermal-throttle ;; 3:consequence) printf frequency-limited ;;
        4:subject) printf usb-2-1 ;; 4:incident) printf device-reset ;; 4:consequence) printf device-reenumerated ;;
        *) die "unknown kernel field: $index:$field" ;;
    esac
}

fresh_case
host=$(hostname_for database)
profile=$(( $(hex_byte "$(derive_hex profile)" 0) % 5 ))
profile_id=$(profile_field "$profile" id)
target=$(( $(hex_byte "$(derive_hex target)" 0) % 5 ))
subject=$(kernel_field "$target" subject)
incident=$(kernel_field "$target" incident)
consequence=$(kernel_field "$target" consequence)
event_time=$(iso_time timestamp 0)
case_id="KRN-$(hex_fragment kernel-case 8)"

mkdir -p "$CASE_DIR/hosts/$host/collected"
kernel_log="$CASE_DIR/hosts/$host/collected/kernel.log"
{
    echo "# Combined capture from dmesg --time-format iso and journalctl -k"
    printf '%sZ %s kernel: Linux version %s\n' "$(iso_time layout 0)" "$host" "$(profile_field "$profile" kernel)"
    printf '%sZ %s kernel: e1000: eth0 NIC Link is Up 1000 Mbps Full Duplex\n' "$(iso_time noise 0)" "$host"
    printf '%sZ %s kernel: audit: type=1400 operation=profile_load name=system-default\n' "$(iso_time noise 3)" "$host"
    case "$target" in
        0)
            printf '%sZ %s kernel: blk_update_request: I/O error, dev %s, sector 314159\n' "$event_time" "$host" "$subject"
            printf '%sZ %s kernel: EXT4-fs error (device %s1): journal I/O failure\n' "$event_time" "$host" "$subject"
            printf '%sZ %s kernel: EXT4-fs (%s1): Remounting filesystem read-only\n' "$event_time" "$host" "$subject" ;;
        1)
            printf '%sZ %s kernel: Out of memory: Killed process 4242 (%s) total-vm:812000kB\n' "$event_time" "$host" "$subject"
            printf '%sZ %s systemd[1]: %s.service: Main process exited, code=killed, status=9/KILL\n' "$event_time" "$host" "$subject"
            printf '%sZ %s systemd[1]: Restarted %s.service.\n' "$event_time" "$host" "$subject" ;;
        2)
            printf '%sZ %s kernel: e1000: %s NIC Link is Down\n' "$event_time" "$host" "$subject"
            printf '%sZ %s networkd: %s: Lost carrier\n' "$event_time" "$host" "$subject"
            printf '%sZ %s kernel: e1000: %s NIC Link is Up 1000 Mbps Full Duplex\n' "$event_time" "$host" "$subject" ;;
        3)
            printf '%sZ %s kernel: CPU0: Core temperature above threshold, cpu clock throttled\n' "$event_time" "$host"
            printf '%sZ %s kernel: thermal thermal_zone0: critical temperature reached: 97 C\n' "$event_time" "$host"
            printf '%sZ %s kernel: CPU0: frequency limited until temperature normalizes\n' "$event_time" "$host" ;;
        *)
            printf '%sZ %s kernel: usb 2-1: reset high-speed USB device number 4\n' "$event_time" "$host"
            printf '%sZ %s kernel: usb 2-1: device descriptor read/64, error -71\n' "$event_time" "$host"
            printf '%sZ %s kernel: usb 2-1: new high-speed USB device number 5\n' "$event_time" "$host" ;;
    esac
} > "$kernel_log"

{
    echo "KERNEL_INCIDENT_CASE"
    echo "CASE_ID=$case_id"
    echo "TARGET_HOST=$host"
    echo "EVENT_TIME=${event_time}Z"
    echo "REMOTE_PROFILE=$profile_id"
    echo "Identify the subject, incident, and resulting consequence at that time."
} > "$CASE_DIR/CASE.txt"

answer="$subject|$incident|$consequence"
write_readme "Inspect the kernel capture at EVENT_TIME from evidence/CASE.txt. Canonical codes use lowercase words separated by hyphens. Submit: subject|incident-code|consequence-code"
record_answer "$answer"
finish_level

