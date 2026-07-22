#!/bin/sh
set -eu
. "$INSTALL_ROOT/resources.sh"

fresh_case
host=$(hostname_for gateway)
profile_hex=$(derive_hex profile)
profile=$(( $(hex_byte "$profile_hex" 0) % 5 ))
auth_name=$(profile_field "$profile" auth)
mkdir -p "$CASE_DIR/hosts/$host/var/log"
auth_log="$CASE_DIR/hosts/$host/var/log/$auth_name"
: > "$auth_log"

answer_hex=$(derive_hex answer)
users="admin root oracle backup deploy test guest support"
target_user=$(pick_from_words "$users" "$(hex_byte "$answer_hex" 0)")
target_ip=$(doc_ip answer-source)
count=$((6 + $(hex_byte "$answer_hex" 1) % 10))
base_time=$(syslog_time timestamp 0)

i=1
while [ "$i" -le 30 ]; do
    noise_user="scanner-$i"
    case "$((i % 3))" in
        0) noise_ip="192.0.2.$((1 + i * 7 % 254))" ;;
        1) noise_ip="198.51.100.$((1 + i * 11 % 254))" ;;
        *) noise_ip="203.0.113.$((1 + i * 13 % 254))" ;;
    esac
    printf '%s %s sshd[%d]: Failed password for invalid user %s from %s port %d ssh2\n' \
        "$base_time" "$host" "$((2000 + i))" "$noise_user" "$noise_ip" "$((30000 + i))" >> "$auth_log"
    i=$((i + 1))
done

i=1
while [ "$i" -le "$count" ]; do
    printf '%s %s sshd[%d]: Invalid user %s from %s port %d\n' \
        "$base_time" "$host" "$((4100 + i))" "$target_user" "$target_ip" "$((42000 + i))" >> "$auth_log"
    printf '%s %s sshd[%d]: Failed password for invalid user %s from %s port %d ssh2\n' \
        "$base_time" "$host" "$((4100 + i))" "$target_user" "$target_ip" "$((42000 + i))" >> "$auth_log"
    i=$((i + 1))
done
printf '%s %s sudo: localadmin : authentication failure ; tty=pts/0 ; user=root\n' \
    "$base_time" "$host" >> "$auth_log"

{
    echo "SSH_AUTHENTICATION_CASE"
    echo "TARGET_HOST=$host"
    echo "TARGET_SOURCE=$target_ip"
    echo "LOG_STYLE=$(profile_field "$profile" id)"
    echo "Count only 'Failed password' records. Related 'Invalid user' records are not additional attempts."
} > "$CASE_DIR/CASE.txt"

answer="$target_user|$target_ip|$count"
write_readme "Inspect the authentication log identified by evidence/CASE.txt. For TARGET_SOURCE, find the invalid username and count only Failed password records. Submit: username|source-ip|count"
record_answer "$answer"
finish_level

