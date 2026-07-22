#!/bin/sh
set -eu

cd "$(dirname "$0")"
INSTALL_ROOT=$(pwd)
export INSTALL_ROOT
. "$INSTALL_ROOT/resources.sh"

SYSTEM_PASSWORD=${SYSTEM_PASSWORD:-systemPassword}
LEVEL_PASSWORD_ROOT=${LEVEL_PASSWORD_ROOT:-levelPassword}
currentDate=${CURRENT_DATE:-$(date +%Y-%m-%d)}
export SYSTEM_PASSWORD LEVEL_PASSWORD_ROOT currentDate

NON_INTERACTIVE=0
NO_LOGIN=0
for arg in "$@"; do
    case "$arg" in
        --non-interactive) NON_INTERACTIVE=1 ;;
        --no-login) NO_LOGIN=1 ;;
        *) die "unknown option: $arg" ;;
    esac
done

if [ "$NON_INTERACTIVE" -eq 1 ]; then
    USER_ID=${USER_ID:-student@example.edu}
else
    confirmation=n
    while [ "$confirmation" != y ]; do
        printf 'Enter your email address (e.g. xyz1234@psu.edu): '
        IFS= read -r USER_ID
        printf 'Is %s your email address? (y/n) ' "$USER_ID"
        IFS= read -r confirmation
    done
fi
export USER_ID

for cmd in adduser awk base64 basename cat chmod chown cp cut date dirname find \
    grep gzip head id ln mkdir passwd printf rm sed sha256sum sort su tail tr \
    uniq wc xxd; do
    command_required "$cmd"
done

mkdir -p /home /srv/log-collector/cases /var/lib/system-logs/answers
chmod 700 /var/lib/system-logs /var/lib/system-logs/answers
ANSWER_DIR=/var/lib/system-logs/answers
export ANSWER_DIR

cp "$INSTALL_ROOT/profile" /etc/profile
for command_file in nextlevel prevlevel checklevel; do
    cp "$INSTALL_ROOT/$command_file" "/usr/bin/$command_file"
    chmod 755 "/usr/bin/$command_file"
done

echo "Building 10 System Information and Logs levels"
levelnumber=1
while [ "$levelnumber" -le 10 ]; do
    levelToBuild="level$levelnumber"
    LEVEL_HOME="/home/$levelToBuild"
    levelPassword="${LEVEL_PASSWORD_ROOT}${levelnumber}"
    level_HASH=$(printf '%s%s%s%s' "$USER_ID" "$currentDate" \
        "$SYSTEM_PASSWORD" "$levelPassword" | sha256sum | awk '{print $1}')
    export levelnumber levelToBuild LEVEL_HOME levelPassword level_HASH

    if ! id "$levelToBuild" >/dev/null 2>&1; then
        adduser -D -g "System Logs learner" "$levelToBuild"
    fi
    passwd -d "$levelToBuild" >/dev/null 2>&1 || true
    case "$LEVEL_HOME" in
        /home/level[1-9]|/home/level10) rm -rf "$LEVEL_HOME" ;;
        *) die "refusing to reset unexpected home: $LEVEL_HOME" ;;
    esac
    mkdir -p "$LEVEL_HOME"

    echo "  $levelToBuild"
    sh "$INSTALL_ROOT/$levelToBuild.sh"
    levelnumber=$((levelnumber + 1))
done

echo "Build complete. Run ./verify.sh to validate generated levels."
if [ "$NO_LOGIN" -eq 0 ]; then
    exec su -l level1
fi
