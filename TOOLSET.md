# Buildroot command requirements

The exercise generator and reference verifier require:

```text
adduser awk base64 basename cat chmod chown cp cut date dirname find grep gzip
head id ln mkdir passwd printf rm sed sha256sum sort su tail tr uniq wc xxd
```

Learners benefit from `less`; the exercise remains solvable with `cat`, `grep`,
`awk`, `sort`, `uniq`, `wc`, `find`, and `gzip`.

No live systemd journal or binary `wtmp` parser is required. Those artifacts
are represented as explicitly labeled command-output captures from remote
systems. `sudo` is intentionally not required; collected evidence is readable
by the owning level account while answer files remain root-only.
