#!/bin/sh
set -eu
. "$INSTALL_ROOT/resources.sh"

fresh_case
mkdir -p "$CASE_DIR/inventory"

profile_hex=$(derive_hex profile)
target_hex=$(derive_hex target)
target_index=$(( $(hex_byte "$target_hex" 0) % 5 ))
target_profile=$(( $(hex_byte "$profile_hex" 0) % 5 ))
roles="gateway application database backup admin"

i=0
for role in $roles; do
    host=$(hostname_for "$role")
    profile=$(( (target_profile + i + 1) % 5 ))
    [ "$i" -ne "$target_index" ] || profile=$target_profile
    host_dir="$CASE_DIR/inventory/$host"
    mkdir -p "$host_dir"
    write_os_release "$profile" "$host_dir/os-release"
    kernel=$(profile_field "$profile" kernel)
    arch=$(profile_field "$profile" arch)
    printf 'Linux %s %s #1 SMP PREEMPT_DYNAMIC %s GNU/Linux\n' \
        "$host" "$kernel" "$arch" > "$host_dir/uname.txt"
    {
        printf 'HOSTNAME=%s\n' "$host"
        printf 'ROLE=%s\n' "$role"
        printf 'DISTRIBUTION_LABEL=%s\n' "$(profile_field "$profile" label)"
        printf 'ASSET=PSU-%04d\n' "$((1000 + (i * 719 + $(hex_byte "$target_hex" "$((i + 1))")) % 9000))"
        printf 'CAPTURED=%sZ\n' "$(iso_time layout "$i")"
    } > "$host_dir/inventory.conf"
    if [ "$i" -eq "$target_index" ]; then
        target_host=$host
        target_role=$role
        target_asset=$(sed -n 's/^ASSET=//p' "$host_dir/inventory.conf")
        target_kernel=$kernel
        target_arch=$arch
    fi
    i=$((i + 1))
done

mkdir -p "$CASE_DIR/inventory/$target_host/history"
old_profile=$(( (target_profile + 4) % 5 ))
write_os_release "$old_profile" "$CASE_DIR/inventory/$target_host/history/os-release.previous"
printf 'This is a stale pre-rebuild snapshot.\n' > "$CASE_DIR/inventory/$target_host/history/NOTICE.txt"

{
    echo "Fleet inventory assignment"
    echo "TARGET_ASSET=$target_asset"
    echo "TARGET_ROLE=$target_role"
    echo "Use the current files in the matching host directory; ignore history/."
} > "$CASE_DIR/ASSIGNMENT.txt"

distro=$(profile_field "$target_profile" label)
answer="$target_host|$distro|$target_kernel|$target_arch"
write_readme "The Buildroot VM is a collection console. Inspect evidence/ASSIGNMENT.txt, locate the assigned remote host, and use its current os-release, uname.txt, and inventory.conf files. Submit: hostname|distribution-version|kernel|architecture. Use the hyphenated distribution label implied by PRETTY_NAME, as shown in this example: host|Debian-12.10|6.1.0-35-amd64|x86_64"
record_answer "$answer"
finish_level
