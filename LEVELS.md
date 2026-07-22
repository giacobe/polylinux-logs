# Level design

| Level | Evidence and format | Task | Exact answer shape |
|---|---|---|---|
| 1 | `os-release`, `uname`, inventory manifests | Identify a remote host profile | `host\|distro-version\|kernel\|arch` |
| 2 | captured `journalctl --list-boots` output | Identify current boot | `boot-id\|ISO-time\|previous-count` |
| 3 | exported systemd unit logs | Diagnose a failed service | `unit\|cause-code\|ISO-time` |
| 4 | Debian `auth.log` or RHEL `secure` | Count SSH failures | `user\|source-ip\|count` |
| 5 | captured `last -Fai` and `lastb -Fai` tables | Identify a successful session | `user\|source-ip\|minutes` |
| 6 | cron syslog plus job output | Diagnose scheduled work | `user\|command\|exit-status` |
| 7 | APT/dpkg or DNF/RPM logs | Find a package change | `operation\|package\|old\|new` |
| 8 | Nginx combined log, JSONL, stack trace | Correlate a web request | `ip\|request-id\|status\|error-code` |
| 9 | kernel/dmesg-style multiline records | Identify a kernel incident | `subject\|incident\|consequence` |
| 10 | rotated multi-host incident bundle | Reconstruct root cause | `root-event\|service\|first-failure-UTC` |

## Generator invariants

- The source format and learning objective of a level never change.
- Distro-specific paths and syntax come from coherent profiles.
- Correct values are derived before noise is generated.
- Noise is adjusted when necessary so it cannot equal a target selector.
- Every README states the exact canonical answer format.
- No answer depends on directory enumeration or record ordering.
- Each level has a reference solver in `verify.sh`.
- Level 10 is narratively cumulative but does not require prior answers.

