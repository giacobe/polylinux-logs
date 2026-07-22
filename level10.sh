#!/bin/sh
set -eu
. "$INSTALL_ROOT/resources.sh"

scenario_field() {
    index=$1
    field=$2
    case "$index:$field" in
        0:root) printf package-upgrade ;; 0:service) printf report-api.service ;; 0:status) printf 503 ;;
        0:detail) printf 'configuration directive cache_backend is no longer valid' ;;
        1:root) printf configuration-edit ;; 1:service) printf gateway-proxy.service ;; 1:status) printf 502 ;;
        1:detail) printf 'upstream block contains an invalid address' ;;
        2:root) printf disk-io-error ;; 2:service) printf document-store.service ;; 2:status) printf 500 ;;
        2:detail) printf 'database filesystem became read-only' ;;
        3:root) printf memory-exhaustion ;; 3:service) printf analytics-worker.service ;; 3:status) printf 503 ;;
        3:detail) printf 'worker killed by out-of-memory handler' ;;
        4:root) printf certificate-renewal-failure ;; 4:service) printf public-gateway.service ;; 4:status) printf 525 ;;
        4:detail) printf 'renewed certificate could not be loaded' ;;
        *) die "unknown scenario field: $index:$field" ;;
    esac
}

fresh_case
admin_host=$(hostname_for admin)
app_host=$(hostname_for application)
gateway_host=$(hostname_for gateway)
scenario=$(( $(hex_byte "$(derive_hex target)" 0) % 5 ))
root_event=$(scenario_field "$scenario" root)
service=$(scenario_field "$scenario" service)
status=$(scenario_field "$scenario" status)
detail=$(scenario_field "$scenario" detail)
case_id="INC-$(hex_fragment incident 10)"
correlation="corr-$(hex_fragment correlation 12)"
time_hex=$(derive_hex timestamp)
event_hour=$(range_from_byte "$(hex_byte "$time_hex" 0)" 8 18)
event_minute=$(range_from_byte "$(hex_byte "$time_hex" 1)" 0 39)
event_second=$(range_from_byte "$(hex_byte "$time_hex" 2)" 0 49)
root_time=$(printf '%sT%02d:%02d:%02dZ' "$currentDate" "$event_hour" "$event_minute" "$event_second")
failure_time=$(printf '%sT%02d:%02d:%02dZ' "$currentDate" "$event_hour" "$((event_minute + 5))" "$((event_second + 3))")
recovery_time=$(printf '%sT%02d:%02d:%02dZ' "$currentDate" "$event_hour" "$((event_minute + 15))" "$((event_second + 7))")
source=$(doc_ip incident-source)

mkdir -p "$CASE_DIR/hosts/$admin_host/var/log" \
    "$CASE_DIR/hosts/$app_host/var/log" \
    "$CASE_DIR/hosts/$gateway_host/var/log/nginx" \
    "$CASE_DIR/aggregate"

auth="$CASE_DIR/hosts/$admin_host/var/log/auth.log"
system="$CASE_DIR/hosts/$app_host/var/log/system.log"
package="$CASE_DIR/hosts/$app_host/var/log/package-history.log"
access="$CASE_DIR/hosts/$gateway_host/var/log/nginx/access.log"
{
    printf '%s %s sshd[2100]: Accepted publickey for operator from %s port 44221 ssh2\n' "$root_time" "$admin_host" "$source"
    printf '%s %s sudo: operator : COMMAND=/usr/local/sbin/case-action --case %s\n' "$root_time" "$admin_host" "$case_id"
    printf '%s %s sshd[2199]: Accepted publickey for auditor from 192.0.2.10 port 55110 ssh2\n' "$(iso_time noise 0)Z" "$admin_host"
} > "$auth"

{
    printf '%s transaction=%s action=%s service=%s\n' "$root_time" "$case_id" "$root_event" "$service"
    printf '%s transaction=routine-001 action=security-update package=ca-certificates\n' "$(iso_time noise 3)Z"
} > "$package"

{
    printf '%s %s systemd[1]: Starting %s correlation=%s\n' "$root_time" "$app_host" "$service" "$correlation"
    printf '%s %s %s: ERROR %s correlation=%s\n' "$failure_time" "$app_host" "$service" "$detail" "$correlation"
    printf '%s %s systemd[1]: %s entered failed state correlation=%s\n' "$failure_time" "$app_host" "$service" "$correlation"
    printf '%s %s systemd[1]: Recovered %s after operator action correlation=%s\n' "$recovery_time" "$app_host" "$service" "$correlation"
    printf '%s %s systemd[1]: metrics-agent.service emitted a transient warning\n' "$(iso_time noise 6)Z" "$app_host"
} > "$system"

i=1
while [ "$i" -le 50 ]; do
    printf '192.0.2.%d - - [%s] "GET /health HTTP/1.1" 200 32 request_id=noise-%03d\n' \
        "$((20 + i % 100))" "$currentDate:12:$(printf '%02d' $((i % 60))):00 +0000" "$i"
    i=$((i + 1))
done > "$access"
printf '%s - - [%s] "GET /case/%s HTTP/1.1" %s 91 request_id=%s\n' \
    "$source" "$(nginx_time_from_iso "$failure_time")" "$case_id" "$status" "$correlation" >> "$access"

{
    printf '%s host=%s case=%s event=root-change code=%s correlation=%s\n' "$root_time" "$app_host" "$case_id" "$root_event" "$correlation"
    printf '%s host=%s case=%s event=service-failure service=%s correlation=%s\n' "$failure_time" "$app_host" "$case_id" "$service" "$correlation"
    printf '%s host=%s case=%s event=external-failure status=%s correlation=%s\n' "$failure_time" "$gateway_host" "$case_id" "$status" "$correlation"
    printf '%s host=%s case=%s event=recovery service=%s correlation=%s\n' "$recovery_time" "$app_host" "$case_id" "$service" "$correlation"
    i=1
    while [ "$i" -le 25 ]; do
        printf '%s host=noise-%d case=ROUTINE event=health-check status=ok correlation=noise-%d\n' \
            "$(iso_time "timeline-noise-$i" 0)Z" "$i" "$i"
        i=$((i + 1))
    done
} > "$CASE_DIR/aggregate/timeline.log.1"
gzip -c "$CASE_DIR/aggregate/timeline.log.1" > "$CASE_DIR/aggregate/timeline.log.1.gz"
rm "$CASE_DIR/aggregate/timeline.log.1"

{
    echo "MULTI_HOST_INCIDENT_CASE"
    echo "CASE_ID=$case_id"
    echo "CORRELATION_ID=$correlation"
    echo "All canonical timeline records use UTC (Z)."
    echo "One aggregate rotation is gzip-compressed."
    echo "Determine the initiating root-event code, affected service, and first externally visible failure time."
} > "$CASE_DIR/CASE.txt"

answer="$root_event|$service|$failure_time"
write_readme "Reconstruct the incident named in evidence/CASE.txt across authentication, package/change, service, web, and aggregate logs. Symptoms are not the root event. Submit: root-event-code|service|YYYY-MM-DDTHH:MM:SSZ"
record_answer "$answer"
finish_level
