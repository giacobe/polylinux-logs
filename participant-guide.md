---
title: "PolyLinux Logs"
short_title: "Logs"
panel_title: "Learning Path"
form_url: "https://forms.microsoft.com/Pages/ResponsePage.aspx?id=RY30fNs9iUOpwcEVUm61LvTNagO6dAdDlZnocMnGFFZUREk0MVJBRlRRTjhBRDRQVzVTRkZETjJOSi4u"

---

# System Information and Logs

In this lab you will investigate system information and log evidence collected
from several Linux hosts. You are working from a small Buildroot virtual
machine that acts as a **collection console**. Most files you examine describe
remote Ubuntu, Debian, Fedora, Rocky Linux, or AlmaLinux systems—not the
Buildroot console itself.

Throughout the lab:

- Read `README.txt` at the beginning of every level.
- Treat `evidence/CASE.txt` or `evidence/ASSIGNMENT.txt` as the case briefing.
- Pay attention to the originating hostname and Linux distribution.
- Search for evidence without modifying the collected files.
- Submit one exact answer string for each level.
- Preserve capitalization, punctuation, hyphens, and pipe characters.

The levels share one fleet and one analyst-console story, but each level is an
independent case. If you get stuck, you may move to another level and return
later.

## Get On the Machine

Wait for the virtual machine on the right to finish booting. At the login
prompt, enter:

```text
root
```

No password is required. Press **Enter**.

If prompted, enter and confirm your email address. The exercise displays an
exercise code and uses your normalized address, the code's date, and exercise
passwords to build deterministic evidence. One of sixteen fictional themes is
used throughout the attempt. You enter `level1` as soon as it is ready while
the other levels continue building in parallel.

## Understand the Collection Console

The console stores each case beneath a central collection directory. Your home
directory contains a convenient link named `evidence` that opens the current
case:

```sh
pwd
ls -la
cat README.txt
ls -la evidence
```

You may see paths such as:

```text
evidence/hosts/HOSTNAME/var/log/
evidence/hosts/HOSTNAME/collected/
evidence/inventory/HOSTNAME/
evidence/aggregate/
```

Files under `collected/` are saved outputs from commands that ran on a remote
host. A heading such as this tells you the original command:

```text
# Captured output: journalctl --list-boots --no-pager
```

Do not run `uname`, `journalctl`, or `last` on the Buildroot console and assume
that the result describes the investigated host. Read the collected evidence.

## Quick Reference

| Task | Command |
|---|---|
| Show the current directory | `pwd` |
| List files, including hidden files | `ls -la` |
| Display a short file | `cat filename` |
| Read the beginning of a file | `head filename` |
| Read the end of a file | `tail filename` |
| Search for text | `grep 'pattern' filename` |
| Search recursively | `grep -r 'pattern' directory` |
| Ignore case while searching | `grep -i 'pattern' filename` |
| Count matching lines | `grep 'pattern' filename \| wc -l` |
| Display selected columns | `awk '{print $1, $3}' filename` |
| Sort lines | `sort filename` |
| Count repeated values | `sort filename \| uniq -c` |
| Find files by name | `find evidence -name 'filename'` |
| Find all files | `find evidence -type f` |
| Read a gzip-compressed log | `gzip -dc filename.gz` |
| Search a compressed log | `gzip -dc filename.gz \| grep 'pattern'` |
| Move to the next level | `nextlevel` |
| Move to the previous level | `prevlevel` |

The pipe character typed between commands is `|`. The same character separates
fields in many submitted answers.

## General Investigation Workflow

At each level, begin with:

```sh
cat README.txt
cat evidence/CASE.txt
find evidence -type f
```

Level 1 uses `ASSIGNMENT.txt` instead of `CASE.txt`.

A useful workflow is:

1. Identify the target host, asset, time, path, transaction, or session.
2. Locate the evidence source that contains that identifier.
3. Filter only the records relevant to the question.
4. Check nearby or correlated records for context.
5. Assemble the fields in the exact order shown in `README.txt`.

Do not submit quotation marks around an answer.

## Level 1: Identify a Collected Host

### Goal

Identify the operating-system profile of a remote fleet member. The inventory
contains several hosts and may include stale historical data.

### Start the investigation

```sh
cat evidence/ASSIGNMENT.txt
find evidence/inventory -type f
```

Locate the host whose `inventory.conf` contains the assigned asset number. Then
inspect its current files:

```sh
cat evidence/inventory/HOSTNAME/inventory.conf
cat evidence/inventory/HOSTNAME/os-release
cat evidence/inventory/HOSTNAME/uname.txt
```

Replace `HOSTNAME` with the directory you discovered. Do not use files beneath
`history/`; those are stale snapshots.

### What to submit

Submit:

```text
hostname|distribution-version|kernel|architecture
```

Use the exact `DISTRIBUTION_LABEL` recorded in `inventory.conf`.

### Continue

```sh
nextlevel
```

## Level 2: Inspect Boot History

### Goal

Determine when the current boot began and how many previous boots are included
in a captured systemd boot listing.

### Start the investigation

```sh
cat evidence/CASE.txt
find evidence -type f
cat evidence/hosts/*/collected/journal-list-boots.txt
```

In `journalctl --list-boots` output, the current boot has offset `0`. Negative
offsets identify earlier boots. Do not confuse application startup messages in
the current-boot journal with the beginning of the boot itself.

### What to submit

Submit:

```text
boot-id|YYYY-MM-DDTHH:MM:SS|previous-count
```

Remove the displayed UTC offset and the `--running` marker from the start time.

### Continue

```sh
nextlevel
```

## Level 3: Find a Failed Service

### Goal

Identify the unresolved service failure and distinguish the underlying cause
from systemd's generic failure summary.

### Start the investigation

```sh
cat evidence/CASE.txt
find evidence -type f
grep -r 'CASE_STATE=' evidence
```

After locating the unresolved unit, read its entire log:

```sh
cat evidence/hosts/*/units/UNIT-NAME.log
```

The application error provides more useful information than a line saying only
that the service failed to start.

### What to submit

Submit:

```text
unit-name|cause-code|YYYY-MM-DDTHH:MM:SS
```

Use the explicit `CAUSE_CODE` and omit the UTC offset from the timestamp.

### Continue

```sh
nextlevel
```

## Level 4: Trace Failed SSH Authentication

### Goal

Find the invalid username targeted from a specified address and count its
failed SSH authentication attempts.

### Start the investigation

```sh
cat evidence/CASE.txt
find evidence -type f
```

Debian-family hosts commonly use `auth.log`; Fedora and RHEL-family hosts
commonly use `secure`. The case tells you which host and source address matter.

Search the appropriate log by source address:

```sh
grep 'SOURCE-ADDRESS' evidence/hosts/*/var/log/*
```

One authentication attempt can produce both an `Invalid user` line and a
`Failed password` line. Follow the case instruction about which record type to
count.

### What to submit

Submit:

```text
username|source-ip|count
```

### Continue

```sh
nextlevel
```

## Level 5: Examine Login History

### Goal

Locate a successful login session in captured login-accounting output and
report its duration.

### Start the investigation

```sh
cat evidence/CASE.txt
find evidence -type f
cat evidence/hosts/*/collected/last-Fai.txt
```

The capture begins with a line naming its columns. Use the target session ID to
select the correct row. The `lastb` capture contains failed login attempts and
is not the successful-session source.

You can filter by the session ID:

```sh
grep 'SESSION-ID' evidence/hosts/*/collected/last-Fai.txt
```

### What to submit

Submit:

```text
username|source-ip|minutes
```

Use the numerical duration column without adding the word `minutes`.

### Continue

```sh
nextlevel
```

## Level 6: Investigate Scheduled Work

### Goal

Correlate a cron execution record with the corresponding job output and report
the account, command, and exit status.

### Start the investigation

```sh
cat evidence/CASE.txt
find evidence -type f
grep -r 'TARGET-RUN-ID' evidence
```

Replace `TARGET-RUN-ID` with the value from `CASE.txt`. The run ID appears in
both the cron record and a job-output file. A later successful retry is not the
run requested by the case.

### What to submit

Submit:

```text
username|command-name|exit-status
```

Use the command name without `/usr/local/sbin/` or its arguments.

### Continue

```sh
nextlevel
```

## Level 7: Diagnose a Package Change

### Goal

Interpret a package-manager transaction from either an APT/dpkg host or a
DNF/RPM host.

### Start the investigation

```sh
cat evidence/CASE.txt
find evidence -type f
```

For an APT case, inspect both:

```text
var/log/apt/history.log
var/log/dpkg.log
```

For a DNF case, inspect both:

```text
var/log/dnf.log
var/log/dnf.rpm.log
```

Use the transaction ID from `CASE.txt`. Other routine transactions are noise.

### What to submit

Submit:

```text
operation|package|old-version|new-version
```

Valid operations include `install`, `upgrade`, `downgrade`, and `remove`. Use
`none` for the missing old version of an installation or the missing new
version of a removal.

### Continue

```sh
nextlevel
```

## Level 8: Correlate a Web Request

### Goal

Connect an Nginx access record to a JSON Lines application error by using a
request ID.

### Start the investigation

```sh
cat evidence/CASE.txt
find evidence -type f
```

First find the specified method and path in the gateway's access log:

```sh
grep 'POST TARGET-PATH' evidence/hosts/*/var/log/nginx/access.log
```

Then search for that record's `request_id` in the application logs:

```sh
grep 'REQUEST-ID' evidence/hosts/*/var/log/polylab-app/*
```

JSON Lines stores one JSON object on each line. The multiline exception file
provides human-readable context, while the JSON record contains the canonical
error code.

### What to submit

Submit:

```text
client-ip|request-id|http-status|error-code
```

### Continue

```sh
nextlevel
```

## Level 9: Analyze Kernel Evidence

### Goal

Interpret a multiline kernel event and identify its affected subject, incident
type, and resulting consequence.

### Start the investigation

```sh
cat evidence/CASE.txt
find evidence -type f
```

Search the kernel capture for the exact event time from the case:

```sh
grep 'EVENT-TIME' evidence/hosts/*/collected/kernel.log
```

Several lines at that timestamp may describe one incident. Read the complete
bundle before deciding which line represents the consequence.

### What to submit

Submit:

```text
subject|incident-code|consequence-code
```

Use lowercase canonical codes with hyphens. The vocabulary in the evidence
maps directly to codes such as `io-error`, `oom-kill`, `link-flap`,
`thermal-throttle`, or `device-reset`.

### Continue

```sh
nextlevel
```

## Level 10: Build an Incident Timeline

### Goal

Correlate authentication, change, service, web, and aggregate records to find
the initiating event and the first externally visible failure.

### Start the investigation

```sh
cat evidence/CASE.txt
find evidence -type f
```

The case supplies both a case ID and a correlation ID. Search the ordinary log
files first:

```sh
grep -r 'CASE-ID' evidence/hosts
grep -r 'CORRELATION-ID' evidence/hosts
```

One normalized aggregate rotation is gzip-compressed. Read or search it without
changing the original:

```sh
gzip -dc evidence/aggregate/timeline.log.1.gz
gzip -dc evidence/aggregate/timeline.log.1.gz | grep 'CASE-ID'
```

Arrange the relevant records by time. A service failure and an HTTP error are
symptoms; look for the earlier change that initiated the sequence.

### What to submit

Submit:

```text
root-event-code|service|YYYY-MM-DDTHH:MM:SSZ
```

The timestamp is the first externally visible failure and must retain the
trailing `Z`.

### Review Earlier Levels

You may return to any earlier case:

```sh
prevlevel
```

Submit each level's answer through the code-submission panel beside the
terminal. The VM does not grade answers or provide correctness feedback.
