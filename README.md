# PolyLinux System Information and Logs

This repository builds a ten-level, deterministic log-analysis exercise for
the Buildroot image used by PolyLinux in v86. The Buildroot guest is presented
as a lightweight collection console. Evidence under `/srv/log-collector`
describes a small fleet of Debian-, Ubuntu-, Fedora-, Rocky-, and AlmaLinux-like
systems; it does not describe the Buildroot guest itself unless explicitly
stated.

## Installation

Run as root inside the exercise image:

```sh
chmod +x install.sh level*.sh verify.sh nextlevel prevlevel checklevel
./install.sh
```

For repeatable image tests:

```sh
USER_ID=student@example.edu CURRENT_DATE=2026-07-21 \
SYSTEM_PASSWORD=exercisePassword ./install.sh --non-interactive --no-login
./verify.sh
```

The installer creates users `level1` through `level10`, stores each level's
evidence under `/srv/log-collector/cases/levelN`, and places a convenient
`evidence` symlink in the corresponding home directory. Expected answers are
root-only files under `/var/lib/system-logs/answers`.

Developers can generate fixtures without creating system accounts by setting
`CASE_ROOT`, `ANSWER_DIR`, `LEVEL_HOME`, and `SKIP_OWNERSHIP=1` before invoking
an individual level script with the normal exported seed variables.

Run the complete unprivileged generator and solver test with:

```sh
sh ./test.sh
```

## Seed contract

Each level hashes this exact byte sequence without separators or a trailing
newline:

```text
email + ISO_date + exercise_password + level_password
```

The level seed is SHA-256. Labeled SHA-256 sub-hashes independently select
answers, profiles, names, timestamps, layout, noise, and optional Easter eggs.
The default level passwords are `levelPassword1` through `levelPassword10`.

## Learner model

Levels share host roles and a centralized-collector narrative, but each case
contains everything necessary to solve it. `nextlevel` and `prevlevel` switch
between passwordless level accounts, so a learner may skip a level.

See `LEVELS.md` for the curriculum and `TOOLSET.md` for command requirements.
