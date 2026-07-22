#!/bin/sh
set -eu
. "$INSTALL_ROOT/resources.sh"

web_field() {
    index=$1
    field=$2
    case "$index:$field" in
        0:path) printf /api/reports/monthly ;; 0:status) printf 504 ;; 0:error) printf DB_TIMEOUT ;;
        0:message) printf 'database query exceeded 30 seconds' ;;
        1:path) printf /api/documents/render ;; 1:status) printf 500 ;; 1:error) printf INVALID_DOCUMENT ;;
        1:message) printf 'renderer rejected malformed document' ;;
        2:path) printf /api/accounts/export ;; 2:status) printf 502 ;; 2:error) printf UPSTREAM_REFUSED ;;
        2:message) printf 'connection to export worker refused' ;;
        3:path) printf /api/archive/write ;; 3:status) printf 500 ;; 3:error) printf STORAGE_DENIED ;;
        3:message) printf 'archive destination permission denied' ;;
        *) die "unknown web field: $index:$field" ;;
    esac
}

fresh_case
gateway=$(hostname_for gateway)
application=$(hostname_for application)
mkdir -p "$CASE_DIR/hosts/$gateway/var/log/nginx" "$CASE_DIR/hosts/$application/var/log/polylab-app"
answer_hex=$(derive_hex answer)
target=$(( $(hex_byte "$answer_hex" 0) % 4 ))
path=$(web_field "$target" path)
status=$(web_field "$target" status)
error=$(web_field "$target" error)
message=$(web_field "$target" message)
client=$(doc_ip answer-client)
request="req-$(hex_fragment request 12)"
event_time="$(iso_time timestamp 0)Z"
access="$CASE_DIR/hosts/$gateway/var/log/nginx/access.log"
app="$CASE_DIR/hosts/$application/var/log/polylab-app/application.jsonl"
: > "$access"
: > "$app"

i=1
while [ "$i" -le 80 ]; do
    case "$((i % 3))" in
        0) noise_ip="192.0.2.$((1 + i * 3 % 254))" ;;
        1) noise_ip="198.51.100.$((1 + i * 5 % 254))" ;;
        *) noise_ip="203.0.113.$((1 + i * 7 % 254))" ;;
    esac
    noise_request="req-noise-$(printf '%03d' "$i")"
    noise_path="/assets/item-$i.css"
    noise_status=$((200 + i % 5))
    printf '%s - - [%s] "GET %s HTTP/1.1" %d 512 "-" "health-agent/1.0" request_id=%s\n' \
        "$noise_ip" "$currentDate:10:$(printf '%02d' $((i % 60))):00 -0400" "$noise_path" "$noise_status" "$noise_request" >> "$access"
    printf '{"timestamp":"%s","level":"info","request_id":"%s","event":"request-complete"}\n' \
        "$(iso_time "noise-web-$i" 0)Z" "$noise_request" >> "$app"
    i=$((i + 1))
done

printf '%s - - [%s] "POST %s HTTP/1.1" %s 173 "-" "PolyLinuxClient/2.0" request_id=%s\n' \
    "$client" "$(nginx_time_from_iso "$event_time")" "$path" "$status" "$request" >> "$access"
printf '{"timestamp":"%s","level":"error","request_id":"%s","error_code":"%s","message":"%s"}\n' \
    "$event_time" "$request" "$error" "$message" >> "$app"
{
    printf '%s ERROR request_id=%s code=%s\n' "$event_time" "$request" "$error"
    echo "Traceback (most recent call last):"
    echo "  File \"worker.py\", line 217, in handle_request"
    printf 'ApplicationError: %s\n' "$message"
} > "$CASE_DIR/hosts/$application/var/log/polylab-app/exceptions.log"

{
    echo "WEB_CORRELATION_CASE"
    echo "TARGET_PATH=$path"
    echo "TARGET_METHOD=POST"
    echo "Correlate gateway and application records with request_id."
} > "$CASE_DIR/CASE.txt"

answer="$client|$request|$status|$error"
write_readme "Find the POST request for TARGET_PATH in the Nginx access log, then correlate its request_id with the JSON Lines application log. Submit: client-ip|request-id|http-status|error-code"
record_answer "$answer"
finish_level
