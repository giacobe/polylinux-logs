#!/bin/sh
set -eu

cd "$(dirname "$0")"
INSTALL_ROOT=$(pwd)
export INSTALL_ROOT

test_root=$(mktemp -d "${TMPDIR:-/tmp}/polylinux-system-logs.XXXXXX")
trap 'rm -rf "$test_root"' EXIT HUP INT TERM

USER_ID=${USER_ID:-student@example.edu}
currentDate=${CURRENT_DATE:-2026-07-21}
SYSTEM_PASSWORD=${SYSTEM_PASSWORD:-exercisePassword}
LEVEL_PASSWORD_ROOT=${LEVEL_PASSWORD_ROOT:-levelPassword}
ANSWER_DIR="$test_root/answers"
CASE_ROOT="$test_root/cases"
SKIP_OWNERSHIP=1
export USER_ID currentDate SYSTEM_PASSWORD LEVEL_PASSWORD_ROOT ANSWER_DIR CASE_ROOT SKIP_OWNERSHIP
mkdir -p "$test_root/home" "$ANSWER_DIR" "$CASE_ROOT"

levelnumber=1
while [ "$levelnumber" -le 10 ]; do
    levelToBuild="level$levelnumber"
    echo "generate $levelToBuild"
    LEVEL_HOME="$test_root/home/$levelToBuild"
    levelPassword="${LEVEL_PASSWORD_ROOT}${levelnumber}"
    level_HASH=$(printf '%s%s%s%s' "$USER_ID" "$currentDate" \
        "$SYSTEM_PASSWORD" "$levelPassword" | sha256sum | awk '{print $1}')
    export levelnumber levelToBuild LEVEL_HOME levelPassword level_HASH
    mkdir -p "$LEVEL_HOME"
    sh "$INSTALL_ROOT/$levelToBuild.sh"
    levelnumber=$((levelnumber + 1))
done

echo "verify generated cases"
CASE_ROOT="$CASE_ROOT" ANSWER_DIR="$ANSWER_DIR" sh "$INSTALL_ROOT/verify.sh"
