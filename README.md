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

Developers can generate fixtures without creating system accounts by setting
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

## Build the browser VM

This lab uses the `basic-compression` configuration from
[`giacobe/buildroot-builder2`](https://github.com/giacobe/buildroot-builder2),
validated with Buildroot `2025.02.15`:

```sh
git clone https://github.com/giacobe/buildroot-builder2.git
cd buildroot-builder2
BUILDROOT_VERSION=2025.02.15 scripts/01-setup-buildroot.sh
scripts/02-build-baseline.sh --config basic-compression
scripts/03-package-payload.sh \
  --repo https://github.com/giacobe/polylinux-logs.git \
  --ref main \
  --baseline artifacts/basic-compression-<timestamp> \
  --output artifacts/polylinux-logs \
  --output-prefix polylinux-logs
```

Replace `<timestamp>` with the stage-2 artifact directory. Review the manifest
and boot-test the exact generated image pair in v86 before publishing.

## Standard runtime contract

The current release uses the reversible PolyBandit exercise code, the versioned `seed-v1` deterministic seed, ten concurrent level generators, staged `README.txt` readiness, unrestricted `nextlevel`/`prevlevel` navigation, and no client-side answer store or checker. See `lab.json` for the authoritative level count, theme policy, Buildroot configuration, and browser artifact names.

Do not rebuild the assigned Buildroot baseline merely to package this lab. Package the repository payload into the configuration named by `buildroot_configuration`, preserve the baseline kernel, and publish the resulting `packaged.bzImage` and `packaged.rootfs.cpio.gz`.
