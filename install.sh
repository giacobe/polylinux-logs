#!/bin/sh
set -eu

cd "$(dirname "$0")"
INSTALL_ROOT=$(pwd)
LAB_ID='system-logs'
LAB_TITLE='System Information and Logs'
SYSTEM_PASSWORD=${SYSTEM_PASSWORD:-systemPassword}
LEVEL_PASSWORD_ROOT=${LEVEL_PASSWORD_ROOT:-levelPassword}
currentDate=${CURRENT_DATE:-$(date +%Y-%m-%d)}
export INSTALL_ROOT LAB_ID LAB_TITLE SYSTEM_PASSWORD LEVEL_PASSWORD_ROOT currentDate

. "$INSTALL_ROOT/resources.sh"
. "$INSTALL_ROOT/polylinux-common.sh"

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
    raw_user=${USER_ID:-student@example.edu}
else
    confirmation=n
    while [ "$confirmation" != y ]; do
        printf 'Enter your email address: '
        IFS= read -r raw_user
        normalized=$(normalize_email "$raw_user")
        validate_email "$normalized" || { echo 'That address is not valid.' >&2; continue; }
        printf 'The exercise will use %s. Is that correct? (y/n) ' "$normalized"
        IFS= read -r confirmation
    done
fi
USER_ID=$(normalize_email "$raw_user")
validate_email "$USER_ID" || die 'invalid email address after normalization'
validate_iso_date "$currentDate" || die 'CURRENT_DATE must be YYYY-MM-DD'
EXERCISE_CODE=$(exercise_code_from_date "$currentDate")
export USER_ID EXERCISE_CODE
select_theme
THEME_OFFSET=$THEME_INDEX
THEME_STEP=0
export THEME_OFFSET THEME_STEP

for cmd in adduser awk base64 basename cat chmod chown cp cut date dirname find grep gzip head id ln mkdir mv passwd printf rm sed sha256sum sleep sort su tail tr uniq wc xxd; do command_required "$cmd"; done

mkdir -p /home /srv/log-collector/cases /etc/profile.d

cp "$INSTALL_ROOT/polylinux-colors.sh" /etc/profile.d/polylinux-colors.sh
chmod 644 /etc/profile.d/polylinux-colors.sh
cp "$INSTALL_ROOT/profile" /etc/profile
for helper in nextlevel prevlevel; do
    cp "$INSTALL_ROOT/$helper" "/usr/bin/$helper"
    chmod 755 "/usr/bin/$helper"
done

. "$INSTALL_ROOT/polylinux-parallel-runtime.sh"
prepare_standard_accounts
echo "Exercise code: $EXERCISE_CODE"
start_standard_levels
