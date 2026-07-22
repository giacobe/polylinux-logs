#!/bin/sh
set -eu
. "$INSTALL_ROOT/resources.sh"

fresh_case
host=$(hostname_for admin)
mkdir -p "$CASE_DIR/hosts/$host/collected"
answer_hex=$(derive_hex answer)
users="alex blair casey devon ellis frankie gray harper"
target_user=$(pick_from_words "$users" "$(hex_byte "$answer_hex" 0)")
target_ip=$(doc_ip answer-source)
minutes=$((20 + $(hex_byte "$answer_hex" 1) % 100))
session_id=$(hex_fragment session 10)
login_time=$(iso_time timestamp 0)

last_file="$CASE_DIR/hosts/$host/collected/last-Fai.txt"
{
    echo "# Captured output normalized from: last -Fai"
    echo "# user tty source login_iso logout_iso duration session_id result"
    i=1
    while [ "$i" -le 12 ]; do
        noise_user="user$i"
        noise_ip="192.0.2.$((20 + i))"
        printf '%s pts/%d %s %s %s %d %s normal\n' \
            "$noise_user" "$((i % 5))" "$noise_ip" "$(iso_time "noise-login-$i" 0)" \
            "$(iso_time "noise-logout-$i" 0)" "$((10 + i * 3))" "$(hex_fragment "noise-session-$i" 10)"
        i=$((i + 1))
    done
    printf '%s pts/7 %s %s recorded-in-accounting %d %s normal\n' \
        "$target_user" "$target_ip" "$login_time" "$minutes" "$session_id"
    printf 'reboot system boot 0.0.0.0 %s still-running 0 boot current\n' "$(iso_time layout 0)"
} > "$last_file"

{
    echo "# Captured output normalized from: lastb -Fai"
    i=1
    while [ "$i" -le 8 ]; do
        printf 'invalid%d ssh:notty 198.51.100.%d %s never 0 failed%d failed\n' \
            "$i" "$((60 + i))" "$(iso_time "failed-$i" 0)" "$i"
        i=$((i + 1))
    done
} > "$CASE_DIR/hosts/$host/collected/lastb-Fai.txt"

{
    echo "LOGIN_HISTORY_CASE"
    echo "TARGET_HOST=$host"
    echo "TARGET_SESSION_ID=$session_id"
    echo "The capture is normalized to explicit columns because it came from a remote host."
} > "$CASE_DIR/CASE.txt"

answer="$target_user|$target_ip|$minutes"
write_readme "Use evidence/CASE.txt to locate the successful session in the captured last output. Report its username, source address, and duration column in minutes. Do not use lastb, which contains failed logins. Submit: username|source-ip|minutes"
record_answer "$answer"
finish_level

