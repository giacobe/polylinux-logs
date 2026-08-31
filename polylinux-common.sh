#!/bin/sh
# Shared PolyLinux runtime contract. Copy this file into each lab repository.
# Contract versions are intentionally explicit because the VM and grader must agree.

SEED_CONTRACT_VERSION=seed-v1
THEME_CATALOG_VERSION=themes-v1
export SEED_CONTRACT_VERSION THEME_CATALOG_VERSION

poly_die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

command_required() {
    command -v "$1" >/dev/null 2>&1 || poly_die "required command not found: $1"
}

normalize_email() {
    printf '%s' "$1" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' |
        tr '[:upper:]' '[:lower:]'
}

validate_email() {
    value=$1
    [ -n "$value" ] && [ "${#value}" -le 254 ] || return 1
    case "$value" in *' '*|*'@@'*|@*|*@|*.*@*.*@*) return 1 ;; esac
    local_part=${value%%@*}
    domain_part=${value#*@}
    [ "$local_part" != "$value" ] || return 1
    case "$domain_part" in *'@'*|.*|*.|*..*|-*|*-) return 1 ;; esac
    case "$domain_part" in *.*) return 0 ;; *) return 1 ;; esac
}

validate_iso_date() {
    case "$1" in
        [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) return 0 ;;
        *) return 1 ;;
    esac
}

exercise_code_from_date() {
    decimal=$(printf '%s' "$1" | tr -d '-')
    printf '%X\n' "$decimal"
}

# Hash exact UTF-8 bytes separated and terminated by NUL bytes. Never place this
# stream in a shell variable: POSIX shell variables cannot preserve NUL bytes.
level_seed_v1() {
    printf '%s\0%s\0%s\0%s\0%s\0%s\0%s\0' \
        'polylinux-seed-v1' "$LAB_ID" "$USER_ID" "$currentDate" \
        "$SYSTEM_PASSWORD" "$levelPassword" "$levelnumber" |
        sha256sum | awk '{print $1}'
}

theme_seed_v1() {
    printf '%s\0%s\0%s\0%s\0' \
        'polylinux-theme-v1' "$LAB_ID" "$USER_ID" "$currentDate" |
        sha256sum | awk '{print $1}'
}

select_theme() {
    theme_hash=$(theme_seed_v1)
    theme_byte=$(printf '%s' "$theme_hash" | cut -c 1-2)
    THEME_INDEX=$((0x$theme_byte % 16))
    export THEME_INDEX
}

# Stable catalog order for themes-v1. Do not reorder entries within this version.
# Fields are deliberately shell-safe single tokens where they may become answers.
theme_field() {
    field=$1
    # Compatibility aliases used by the first-generation themed labs.
    case "$field" in
        root) field=project ;;
        item) field=asset ;;
        location) field=place ;;
        group) field=org ;;
        category1) field=status ;;
        category2) field=event ;;
    esac
    case "$THEME_INDEX:$field" in
        0:id) printf space-mission ;; 0:title) printf 'Space Mission Control' ;; 0:org) printf AsterVale ;; 0:place) printf launch_bay ;; 0:system) printf telemetry_node ;; 0:project) printf orbit_survey ;; 0:asset) printf star_map ;; 0:event) printf trajectory_update ;; 0:status) printf aligned ;; 0:service) printf telemetry ;; 0:host) printf relay ;; 0:file) printf flight_manifest ;; 0:person) printf Nova_Rellan ;;
        1:id) printf ocean-research ;; 1:title) printf 'Oceanographic Research' ;; 1:org) printf BlueCurrent ;; 1:place) printf reef_station ;; 1:system) printf sonar_array ;; 1:project) printf current_survey ;; 1:asset) printf sample_case ;; 1:event) printf dive_report ;; 1:status) printf surfaced ;; 1:service) printf hydrography ;; 1:host) printf buoy ;; 1:file) printf voyage_log ;; 1:person) printf Mira_Vossen ;;
        2:id) printf wildlife-reserve ;; 2:title) printf 'Wildlife Conservation' ;; 2:org) printf CedarHollow ;; 2:place) printf ranger_post ;; 2:system) printf habitat_sensor ;; 2:project) printf migration_watch ;; 2:asset) printf field_camera ;; 2:event) printf trail_observation ;; 2:status) printf protected ;; 2:service) printf tracking ;; 2:host) printf lookout ;; 2:file) printf habitat_record ;; 2:person) printf Tavi_Merren ;;
        3:id) printf museum-archive ;; 3:title) printf 'Museum Collections' ;; 3:org) printf LumenMuseum ;; 3:place) printf west_gallery ;; 3:system) printf catalog_terminal ;; 3:project) printf archive_review ;; 3:asset) printf exhibit_case ;; 3:event) printf accession_update ;; 3:status) printf cataloged ;; 3:service) printf collections ;; 3:host) printf curator ;; 3:file) printf accession_note ;; 3:person) printf Elian_Sorel ;;
        4:id) printf library-system ;; 4:title) printf 'Library Operations' ;; 4:org) printf NorthwindLibrary ;; 4:place) printf reading_room ;; 4:system) printf catalog_server ;; 4:project) printf index_refresh ;; 4:asset) printf archive_volume ;; 4:event) printf catalog_update ;; 4:status) printf available ;; 4:service) printf catalog ;; 4:host) printf stacks ;; 4:file) printf circulation_record ;; 4:person) printf Orin_Vale ;;
        5:id) printf film-production ;; 5:title) printf 'Film Production' ;; 5:org) printf LanternFrame ;; 5:place) printf sound_stage ;; 5:system) printf editing_console ;; 5:project) printf horizon_cut ;; 5:asset) printf camera_reel ;; 5:event) printf scene_review ;; 5:status) printf approved ;; 5:service) printf dailies ;; 5:host) printf studio ;; 5:file) printf shot_list ;; 5:person) printf Cira_Lenn ;;
        6:id) printf music-festival ;; 6:title) printf 'Music Festival' ;; 6:org) printf MeadowSound ;; 6:place) printf river_stage ;; 6:system) printf mixing_board ;; 6:project) printf evening_program ;; 6:asset) printf instrument_case ;; 6:event) printf sound_check ;; 6:status) printf scheduled ;; 6:service) printf stagefeed ;; 6:host) printf encore ;; 6:file) printf set_list ;; 6:person) printf Jori_Quill ;;
        7:id) printf food-service ;; 7:title) printf 'Restaurant Operations' ;; 7:org) printf JuniperTable ;; 7:place) printf prep_kitchen ;; 7:system) printf order_terminal ;; 7:project) printf seasonal_menu ;; 7:asset) printf pantry_crate ;; 7:event) printf service_update ;; 7:status) printf prepared ;; 7:service) printf ordering ;; 7:host) printf pantry ;; 7:file) printf recipe_card ;; 7:person) printf Nella_Briar ;;
        8:id) printf sports-league ;; 8:title) printf 'Sports League' ;; 8:org) printf SummitLeague ;; 8:place) printf central_field ;; 8:system) printf scoreboard_node ;; 8:project) printf spring_series ;; 8:asset) printf equipment_bin ;; 8:event) printf match_report ;; 8:status) printf confirmed ;; 8:service) printf scoring ;; 8:host) printf sideline ;; 8:file) printf roster_sheet ;; 8:person) printf Rian_Torel ;;
        9:id) printf public-transit ;; 9:title) printf 'Transit Operations' ;; 9:org) printf HarborTransit ;; 9:place) printf union_station ;; 9:system) printf signal_controller ;; 9:project) printf route_refresh ;; 9:asset) printf service_vehicle ;; 9:event) printf schedule_change ;; 9:status) printf on_time ;; 9:service) printf routing ;; 9:host) printf platform ;; 9:file) printf route_manifest ;; 9:person) printf Sela_Morin ;;
        10:id) printf weather-network ;; 10:title) printf 'Weather Monitoring' ;; 10:org) printf ClearSkyNetwork ;; 10:place) printf ridge_station ;; 10:system) printf climate_sensor ;; 10:project) printf storm_watch ;; 10:asset) printf rain_gauge ;; 10:event) printf forecast_update ;; 10:status) printf stable ;; 10:service) printf forecast ;; 10:host) printf barometer ;; 10:file) printf observation_log ;; 10:person) printf Veya_Corin ;;
        11:id) printf renewable-energy ;; 11:title) printf 'Renewable Energy Grid' ;; 11:org) printf BrightFieldEnergy ;; 11:place) printf solar_yard ;; 11:system) printf grid_controller ;; 11:project) printf clean_output ;; 11:asset) printf turbine_unit ;; 11:event) printf output_report ;; 11:status) printf generating ;; 11:service) printf gridwatch ;; 11:host) printf inverter ;; 11:file) printf energy_report ;; 11:person) printf Daro_Lume ;;
        12:id) printf health-clinic ;; 12:title) printf 'Community Clinic Operations' ;; 12:org) printf WillowCareClinic ;; 12:place) printf supply_room ;; 12:system) printf scheduling_terminal ;; 12:project) printf wellness_outreach ;; 12:asset) printf equipment_cart ;; 12:event) printf inventory_review ;; 12:status) printf ready ;; 12:service) printf scheduling ;; 12:host) printf reception ;; 12:file) printf supply_record ;; 12:person) printf Ilya_Fern ;;
        13:id) printf university-research ;; 13:title) printf 'University Research' ;; 13:org) printf WestbridgeInstitute ;; 13:place) printf discovery_lab ;; 13:system) printf research_cluster ;; 13:project) printf prism_study ;; 13:asset) printf sample_tray ;; 13:event) printf experiment_run ;; 13:status) printf reviewed ;; 13:service) printf datasets ;; 13:host) printf scholar ;; 13:file) printf study_notes ;; 13:person) printf Arin_Kest ;;
        14:id) printf manufacturing ;; 14:title) printf 'Manufacturing Plant' ;; 14:org) printf StoneRiverWorks ;; 14:place) printf assembly_hall ;; 14:system) printf line_controller ;; 14:project) printf quality_cycle ;; 14:asset) printf component_bin ;; 14:event) printf inspection_pass ;; 14:status) printf assembled ;; 14:service) printf production ;; 14:host) printf conveyor ;; 14:file) printf work_order ;; 14:person) printf Pera_Dunn ;;
        15:id) printf incident-response ;; 15:title) printf 'Cybersecurity Incident Response' ;; 15:org) printf SilverPineSecurity ;; 15:place) printf response_center ;; 15:system) printf analysis_node ;; 15:project) printf beacon_review ;; 15:asset) printf evidence_bundle ;; 15:event) printf alert_triage ;; 15:status) printf contained ;; 15:service) printf monitoring ;; 15:host) printf sentinel ;; 15:file) printf incident_record ;; 15:person) printf Zerin_Cale ;;
        *) poly_die "unknown theme field: $THEME_INDEX:$field" ;;
    esac
}

theme_variant() {
    field=$1
    ordinal=$2
    printf '%s_%02d\n' "$(theme_field "$field")" "$ordinal"
}

# Materialize the legacy 16-by-16 dictionary shape from the selected theme.
# This keeps the original navigation mechanisms while ensuring every filename
# and distractor belongs visibly to the attempt's theme.
prepare_theme_dictionaries() {
    destination=$1
    case "$destination" in
        /run/polylinux/*/theme-dictionaries|*/theme-dictionaries) ;;
        *) poly_die "refusing unexpected theme dictionary path: $destination" ;;
    esac
    rm -rf "$destination"
    mkdir -p "$destination"
    for key in 0 1 2 3 4 5 6 7 8 9 a b c d e f; do
        case "$key" in
            0|b) field=org ;; 1|c) field=place ;; 2) field=system ;;
            3|d) field=project ;; 4|e) field=asset ;; 5|f) field=event ;;
            6) field=status ;; 7) field=service ;; 8) field=host ;;
            9) field=file ;; a) field=person ;;
        esac
        base=$(theme_field "$field")
        ordinal=0
        while [ "$ordinal" -lt 16 ]; do
            printf '%s_%s_%02d\n' "$base" "$key" "$ordinal"
            ordinal=$((ordinal + 1))
        done > "$destination/dict$key.txt"
    done
}

# Render a complete 40-column terminal box. Legacy level generators may still
# emit partial star borders; normalize those lines here so presentation is
# consistent without coupling the curriculum scripts to terminal formatting.
render_box_file() {
    input=$1
    output=$2
    awk '
        BEGIN {
            width = 36
            border = "****************************************"
            print border
        }
        function boxed(text,    cut, i) {
            if (text == "") {
                printf "* %-36s *\n", ""
                return
            }
            while (length(text) > width) {
                cut = width
                for (i = width; i > 1; i--)
                    if (substr(text, i, 1) == " ") { cut = i - 1; break }
                printf "* %-36s *\n", substr(text, 1, cut)
                text = substr(text, cut + 1)
                sub(/^[[:space:]]+/, "", text)
            }
            printf "* %-36s *\n", text
        }
        {
            line = $0
            if (line == "__POLYLINUX_DIVIDER__") { print border; next }
            if (line ~ /^\*+[[:space:]]*$/) next
            sub(/^\*[[:space:]]?/, "", line)
            sub(/[[:space:]]?\*$/, "", line)
            boxed(line)
        }
        END { print border }
    ' "$input" > "$output"
}

write_pending_readme() {
    home=$1
    mkdir -p "$home"
    raw="$home/.README.pending.$$"
    cat > "$raw" <<'EOF'
This level has not completed building yet.

You may continue to another level or return here shortly.
EOF
    render_box_file "$raw" "$home/README.txt"
    rm -f "$raw"
}

write_failed_readme() {
    home=$1
    level=$2
    tmp="$home/.README.txt.failed.$$"
    raw="$home/.README.failed.raw.$$"
    {
        echo 'This level could not be prepared.'
        echo
        echo 'Restart this lab to try again. If the problem continues, report the'
        printf 'lab name and level number (%s) to your instructor.\n' "$level"
    } > "$raw"
    render_box_file "$raw" "$tmp"
    rm -f "$raw"
    mv "$tmp" "$home/README.txt"
}
