#!/bin/sh

die() {
    echo "ERROR: $*" >&2
    exit 1
}

command_required() {
    command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

derive_hex() {
    label=$1
    printf '%s:%s' "$level_HASH" "$label" | sha256sum | awk '{print $1}'
}

hex_byte() {
    hex=$1
    index=$2
    start=$((index * 2 + 1))
    pair=$(printf '%s' "$hex" | cut -c "$start-$((start + 1))")
    printf '%d\n' "$((0x$pair))"
}

range_from_byte() {
    byte=$1
    minimum=$2
    maximum=$3
    printf '%d\n' "$((minimum + byte % (maximum - minimum + 1)))"
}

pick_from_words() {
    words=$1
    byte=$2
    set -- $words
    count=$#
    wanted=$((byte % count + 1))
    eval "printf '%s\\n' \"\${$wanted}\""
}

base64url_digest() {
    printf '%s' "$1" | xxd -r -p | base64 | tr -d '\r\n=' | tr '+/' '-_'
}

answer_token() {
    length=$1
    answer_hex=$(derive_hex answer)
    base64url_digest "$answer_hex" | cut -c "1-$length"
}

hex_fragment() {
    label=$1
    length=$2
    derive_hex "$label" | cut -c "1-$length"
}

iso_time() {
    label=$1
    offset=$2
    time_hex=$(derive_hex "$label")
    hour=$(range_from_byte "$(hex_byte "$time_hex" "$offset")" 0 23)
    minute=$(range_from_byte "$(hex_byte "$time_hex" "$((offset + 1))")" 0 59)
    second=$(range_from_byte "$(hex_byte "$time_hex" "$((offset + 2))")" 0 59)
    printf '%sT%02d:%02d:%02d' "$currentDate" "$hour" "$minute" "$second"
}

syslog_time() {
    label=$1
    offset=$2
    time_hex=$(derive_hex "$label")
    hour=$(range_from_byte "$(hex_byte "$time_hex" "$offset")" 0 23)
    minute=$(range_from_byte "$(hex_byte "$time_hex" "$((offset + 1))")" 0 59)
    second=$(range_from_byte "$(hex_byte "$time_hex" "$((offset + 2))")" 0 59)
    month=$(printf '%s' "$currentDate" | cut -c 6-7)
    day=$(printf '%s' "$currentDate" | cut -c 9-10 | sed 's/^0/ /')
    case "$month" in
        01) mon=Jan ;; 02) mon=Feb ;; 03) mon=Mar ;; 04) mon=Apr ;;
        05) mon=May ;; 06) mon=Jun ;; 07) mon=Jul ;; 08) mon=Aug ;;
        09) mon=Sep ;; 10) mon=Oct ;; 11) mon=Nov ;; *) mon=Dec ;;
    esac
    printf '%s %2s %02d:%02d:%02d' "$mon" "$day" "$hour" "$minute" "$second"
}

nginx_time_from_iso() {
    iso=$1
    year=$(printf '%s' "$iso" | cut -c 1-4)
    month=$(printf '%s' "$iso" | cut -c 6-7)
    day=$(printf '%s' "$iso" | cut -c 9-10)
    clock=$(printf '%s' "$iso" | cut -c 12-19)
    case "$month" in
        01) mon=Jan ;; 02) mon=Feb ;; 03) mon=Mar ;; 04) mon=Apr ;;
        05) mon=May ;; 06) mon=Jun ;; 07) mon=Jul ;; 08) mon=Aug ;;
        09) mon=Sep ;; 10) mon=Oct ;; 11) mon=Nov ;; *) mon=Dec ;;
    esac
    printf '%s/%s/%s:%s +0000' "$day" "$mon" "$year" "$clock"
}

hostname_for() {
    role=$1
    host_hex=$(derive_hex "names-$role")
    stem=$(pick_from_words "orion atlas nova ember cedar quartz zephyr aurora" "$(hex_byte "$host_hex" 0)")
    suffix=$(range_from_byte "$(hex_byte "$host_hex" 1)" 11 98)
    printf '%s-%s' "$stem" "$suffix"
}

doc_ip() {
    label=$1
    ip_hex=$(derive_hex "$label")
    subnet=$(range_from_byte "$(hex_byte "$ip_hex" 0)" 0 2)
    octet=$(range_from_byte "$(hex_byte "$ip_hex" 1)" 1 254)
    case "$subnet" in
        0) printf '192.0.2.%d' "$octet" ;;
        1) printf '198.51.100.%d' "$octet" ;;
        *) printf '203.0.113.%d' "$octet" ;;
    esac
}

profile_field() {
    profile=$1
    field=$2
    case "$profile:$field" in
        0:id) printf ubuntu ;; 0:label) printf 'Ubuntu-24.04.2-LTS' ;;
        0:pretty) printf 'Ubuntu 24.04.2 LTS' ;; 0:version) printf '24.04' ;;
        0:codename) printf noble ;; 0:kernel) printf '6.8.0-63-generic' ;;
        0:arch) printf x86_64 ;; 0:auth) printf auth.log ;; 0:package) printf apt ;;
        1:id) printf debian ;; 1:label) printf 'Debian-12.10' ;;
        1:pretty) printf 'Debian GNU/Linux 12 (bookworm)' ;; 1:version) printf 12 ;;
        1:codename) printf bookworm ;; 1:kernel) printf '6.1.0-35-amd64' ;;
        1:arch) printf x86_64 ;; 1:auth) printf auth.log ;; 1:package) printf apt ;;
        2:id) printf fedora ;; 2:label) printf 'Fedora-Linux-41' ;;
        2:pretty) printf 'Fedora Linux 41 (Server Edition)' ;; 2:version) printf 41 ;;
        2:codename) printf '' ;; 2:kernel) printf '6.12.8-200.fc41.x86_64' ;;
        2:arch) printf x86_64 ;; 2:auth) printf secure ;; 2:package) printf dnf ;;
        3:id) printf rocky ;; 3:label) printf 'Rocky-Linux-9.5' ;;
        3:pretty) printf 'Rocky Linux 9.5 (Blue Onyx)' ;; 3:version) printf 9.5 ;;
        3:codename) printf '' ;; 3:kernel) printf '5.14.0-503.40.1.el9_5.x86_64' ;;
        3:arch) printf x86_64 ;; 3:auth) printf secure ;; 3:package) printf dnf ;;
        4:id) printf almalinux ;; 4:label) printf 'AlmaLinux-9.5' ;;
        4:pretty) printf 'AlmaLinux 9.5 (Teal Serval)' ;; 4:version) printf 9.5 ;;
        4:codename) printf '' ;; 4:kernel) printf '5.14.0-503.40.1.el9_5.x86_64' ;;
        4:arch) printf x86_64 ;; 4:auth) printf secure ;; 4:package) printf dnf ;;
        *) die "unknown profile field: $profile:$field" ;;
    esac
}

write_os_release() {
    profile=$1
    output=$2
    id=$(profile_field "$profile" id)
    pretty=$(profile_field "$profile" pretty)
    version=$(profile_field "$profile" version)
    codename=$(profile_field "$profile" codename)
    {
        printf 'NAME="%s"\n' "$pretty"
        printf 'ID=%s\n' "$id"
        printf 'VERSION_ID="%s"\n' "$version"
        printf 'PRETTY_NAME="%s"\n' "$pretty"
        [ -z "$codename" ] || printf 'VERSION_CODENAME=%s\n' "$codename"
    } > "$output"
}

write_readme() {
    instructions=$1
    {
        echo "* Collection date: $currentDate"
        echo "* Learner        : $USER_ID"
        echo "************************************************************************"
        echo "* Case instructions"
        echo "************************************************************************"
        printf '%s\n' "$instructions"
    } > "$LEVEL_HOME/README.txt"
}

record_answer() {
    printf '%s\n' "$1" > "$ANSWER_DIR/$levelToBuild"
    chmod 600 "$ANSWER_DIR/$levelToBuild"
}

fresh_case() {
    case "$levelToBuild" in
        level[1-9]|level10) ;;
        *) die "refusing unexpected level name: $levelToBuild" ;;
    esac
    CASE_DIR="${CASE_ROOT:-/srv/log-collector/cases}/$levelToBuild"
    rm -rf "$CASE_DIR"
    mkdir -p "$CASE_DIR"
    ln -s "$CASE_DIR" "$LEVEL_HOME/evidence"
    export CASE_DIR
}

finish_level() {
    if [ "${SKIP_OWNERSHIP:-0}" -eq 1 ]; then
        return
    fi
    chown -R "$levelToBuild:$levelToBuild" "$LEVEL_HOME" "$CASE_DIR"
    find "$CASE_DIR" -type d -exec chmod 750 {} \;
    find "$CASE_DIR" -type f -exec chmod 640 {} \;
    chmod 700 "$LEVEL_HOME"
}
