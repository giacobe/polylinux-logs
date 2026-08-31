#!/bin/sh
# Shared account preparation and parallel level construction for ten-level labs.

MAX_PARALLEL=${MAX_PARALLEL:-10}
case "$MAX_PARALLEL" in
    1|2|3|4|5|6|7|8|9|10) ;;
    *) poly_die 'MAX_PARALLEL must be between 1 and 10' ;;
esac

STATUS_ROOT=${STATUS_ROOT:-/run/polylinux/$LAB_ID}
READY_DIR=$STATUS_ROOT/ready
FAILED_DIR=$STATUS_ROOT/failed
BUILD_LOG=${BUILD_LOG:-/var/log/$LAB_ID-build.log}
HOME_ROOT=${HOME_ROOT:-/home}
export STATUS_ROOT READY_DIR FAILED_DIR BUILD_LOG HOME_ROOT

prepare_standard_accounts() {
    mkdir -p "$HOME_ROOT" "$READY_DIR" "$FAILED_DIR"
    chmod 755 "$STATUS_ROOT" "$READY_DIR" "$FAILED_DIR"
    : > "$BUILD_LOG"
    levelnumber=1
    while [ "$levelnumber" -le 10 ]; do
        levelToBuild="level$levelnumber"
        final_home="$HOME_ROOT/$levelToBuild"
        if [ -z "${CASE_ROOT:-}" ]; then
            if ! id "$levelToBuild" >/dev/null 2>&1; then
                adduser -D -g "$LAB_TITLE learner" "$levelToBuild"
            fi
            passwd -d "$levelToBuild" >/dev/null 2>&1 || true
        fi
        case "$final_home" in
            "$HOME_ROOT"/level[1-9]|"$HOME_ROOT"/level10) rm -rf "$final_home" ;;
            *) poly_die "refusing unexpected level home: $final_home" ;;
        esac
        write_pending_readme "$final_home"
        if [ -z "${CASE_ROOT:-}" ]; then
            chown -R "$levelToBuild:$levelToBuild" "$final_home"
            chmod 700 "$final_home"
        fi
        rm -f "$READY_DIR/$levelToBuild" "$FAILED_DIR/$levelToBuild"
        levelnumber=$((levelnumber + 1))
    done
}

build_standard_level() (
    levelnumber=$1
    levelToBuild="level$levelnumber"
    final_home="$HOME_ROOT/$levelToBuild"
    if [ "${LEGACY_DIRECT:-0}" -eq 1 ]; then
        LEVEL_HOME="$final_home"
        readMeLocation="$final_home/.README.building"
        rm -f "$final_home/.README.building"
        export readMeLocation
    else
        LEVEL_HOME="$HOME_ROOT/.polylinux-build-$LAB_ID-$levelToBuild"
    fi
    levelPassword="${LEVEL_PASSWORD_ROOT}${levelnumber}"
    level_HASH=$(level_seed_v1)
    export levelnumber levelToBuild LEVEL_HOME levelPassword level_HASH
    if [ "${LEGACY_DIRECT:-0}" -ne 1 ]; then
        rm -rf "$LEVEL_HOME"
        mkdir -p "$LEVEL_HOME"
    fi
    if sh "$INSTALL_ROOT/level$levelnumber.sh"; then
        if [ "${LEGACY_DIRECT:-0}" -eq 1 ]; then
            final_readme="$final_home/.README.building"
        else
            final_readme="$LEVEL_HOME/README.txt"
        fi
        raw_readme="$HOME_ROOT/.README-raw-$LAB_ID-$levelToBuild.$$"
        saved_readme="$HOME_ROOT/.README-$LAB_ID-$levelToBuild.$$"
        if [ -f "$final_readme" ]; then
            generated_readme="$HOME_ROOT/.generated-README-$LAB_ID-$levelToBuild.$$"
            mv "$final_readme" "$generated_readme"
            {
                echo "Level: $levelToBuild"
                echo "PolyLinux: $LAB_TITLE"
                echo "Participant: $USER_ID"
                echo "Exercise code: $EXERCISE_CODE"
                echo "Theme: $(theme_field title)"
                echo '__POLYLINUX_DIVIDER__'
                # Some predecessor generators wrote their own metadata. The
                # shared runtime is authoritative, so suppress duplicate rows.
                sed '/^[*[:space:]]*Level[[:space:]]*:/d;/^[*[:space:]]*PolyLinux[[:space:]]*:/d;/^[*[:space:]]*Participant[[:space:]]*:/d;/^[*[:space:]]*Learner[[:space:]]*:/d;/^[*[:space:]]*User[[:space:]]*:/d;/^[*[:space:]]*Exercise code[[:space:]]*:/d;/^[*[:space:]]*Theme[[:space:]]*:/d;/^[*[:space:]]*Generated for[[:space:]]*:/d' "$generated_readme"
            } > "$raw_readme"
            rm -f "$generated_readme"
        else
            {
                echo "Level: $levelToBuild"
                echo "PolyLinux: $LAB_TITLE"
                echo "Participant: $USER_ID"
                echo "Exercise code: $EXERCISE_CODE"
                echo "Theme: $(theme_field title)"
                echo '__POLYLINUX_DIVIDER__'
                echo 'This level is ready.'
            } > "$raw_readme"
        fi
        render_box_file "$raw_readme" "$saved_readme"
        rm -f "$raw_readme"
        if [ "${LEGACY_DIRECT:-0}" -ne 1 ]; then cp -a "$LEVEL_HOME/." "$final_home/"; fi
        mv "$saved_readme" "$final_home/README.txt"
        if [ "${LEGACY_DIRECT:-0}" -ne 1 ]; then rm -rf "$LEVEL_HOME"; fi
        if [ -z "${CASE_ROOT:-}" ]; then
            chown -R "$levelToBuild:$levelToBuild" "$final_home"
            chmod 700 "$final_home"
        fi
        touch "$READY_DIR/$levelToBuild"
        printf '%s ready\n' "$levelToBuild"
        exit 0
    fi
    if [ "${LEGACY_DIRECT:-0}" -ne 1 ]; then rm -rf "$LEVEL_HOME"; fi
    write_failed_readme "$final_home" "$levelToBuild"
    if [ -z "${CASE_ROOT:-}" ]; then chown "$levelToBuild:$levelToBuild" "$final_home/README.txt"; fi
    touch "$FAILED_DIR/$levelToBuild"
    printf '%s failed\n' "$levelToBuild" >&2
    exit 1
)

build_standard_levels() (
    failures=0
    pids=
    running=0
    levelnumber=1
    while [ "$levelnumber" -le 10 ]; do
        build_standard_level "$levelnumber" >> "$BUILD_LOG" 2>&1 &
        pids="$pids $!"
        running=$((running + 1))
        if [ "$running" -eq "$MAX_PARALLEL" ]; then
            for pid in $pids; do wait "$pid" || failures=$((failures + 1)); done
            pids=
            running=0
        fi
        levelnumber=$((levelnumber + 1))
    done
    for pid in $pids; do wait "$pid" || failures=$((failures + 1)); done
    if [ "$failures" -eq 0 ]; then
        touch "$STATUS_ROOT/all-ready"
        exit 0
    fi
    touch "$STATUS_ROOT/build-failed"
    printf '%s level builds failed\n' "$failures" >> "$BUILD_LOG"
    exit 1
)

start_standard_levels() {
    printf 'Preparing 10 %s levels using theme: %s\n' "$LAB_TITLE" "$(theme_field title)"
    # The learner shell replaces the installer as soon as Level 1 is ready.
    # Ignore HUP and detach stdin so the remaining parallel workers survive
    # that handoff and can publish their ready/failed markers.
    (trap '' HUP; build_standard_levels) < /dev/null &
    SUPERVISOR_PID=$!
    if [ "$NO_LOGIN" -eq 1 ] || [ -n "${CASE_ROOT:-}" ]; then
        wait "$SUPERVISOR_PID" || poly_die "one or more levels failed; see $BUILD_LOG"
        printf 'Build complete.\n'
        return
    fi
    while [ ! -f "$READY_DIR/level1" ]; do
        [ ! -f "$FAILED_DIR/level1" ] || poly_die "level1 failed; see $BUILD_LOG"
        sleep 1
    done
    printf 'Level 1 is ready; later levels may still be preparing.\n'
    exec su -l level1
}
