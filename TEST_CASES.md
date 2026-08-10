# YashanDB Installer Test Cases

## Test Environment

Use four disposable Linux VMs with SSH key access: primary `10.0.0.11` and
standbys `10.0.0.12` through `10.0.0.14`. Run every destructive case against
fresh snapshots. Set `PKG=./YashanDB.tar.gz` to a verified installation package.

## CLI and Safety

| ID | Scenario | Command / setup | Expected result |
| --- | --- | --- | --- |
| T-001 | Help is available | `./yinstall.sh --help` | Exit 0; documents `os`, `db`, `standby`, and `clean`. |
| T-002 | Required target is rejected | `./yinstall.sh db install --package "$PKG"` | Non-zero exit; no SSH connection or local change. |
| T-003 | Invalid host is rejected | Use `--primary invalid-host` | Non-zero exit before remote execution. |
| T-004 | Precheck is read-only | Add `--precheck` to every install command | Exit 0 when valid; no package upload, service, or config change. |
| T-005 | Dry run is read-only | Add `--dry-run` to a valid install | Exit 0; planned steps logged; no remote write command. |
| T-006 | Secrets are redacted | Run with a test password | Logs contain no password value. |

## OS Baseline

| ID | Scenario | Command / setup | Expected result |
| --- | --- | --- | --- |
| T-010 | Minimum baseline | `./yinstall.sh os prepare -t 10.0.0.11` | Required user, group, directories, limits, sysctl, dependencies, and firewall rules exist. |
| T-011 | Idempotent baseline | Run T-010 twice | Second run exits 0 and makes no destructive change. |
| T-012 | Unsupported distribution | Use an unsupported VM image | Precheck fails with the distribution and missing capability. |
| T-013 | Port conflict | Occupy the database port before preparation/install | Non-zero exit naming the host and port. |

## Primary Installation

| ID | Scenario | Command / setup | Expected result |
| --- | --- | --- | --- |
| T-020 | Install primary | `./yinstall.sh db install -t 10.0.0.11 --package "$PKG"` | Exit 0; service is active; database accepts a local health query. |
| T-021 | Restart persistence | Reboot host after T-020 | Database service returns to active state automatically. |
| T-022 | Existing installation guard | Run T-020 again without force | Fails or skips safely; existing data and configuration remain intact. |
| T-023 | Bad package | Use a missing or checksum-invalid package | Fails before extraction; no partial installation directory remains. |
| T-024 | Step selection | Install with `--include-steps C-001,C-002` | Only selected steps run; output identifies skipped steps. |

## One Primary, Multiple Standbys

| ID | Scenario | Command / setup | Expected result |
| --- | --- | --- | --- |
| T-030 | Add three standbys | `./yinstall.sh standby add --primary 10.0.0.11 --standbys 10.0.0.12,10.0.0.13,10.0.0.14 --package "$PKG"` | All standby services are active and each reports healthy replication. |
| T-031 | Add one standby later | Complete one standby, then add a second | Existing standby is not reconfigured or restarted. |
| T-032 | Partial target failure | Block SSH or occupy a port on `10.0.0.13` | Other standbys finish; command exits non-zero with per-host summary. |
| T-033 | Primary not ready | Disable archive/replication prerequisite | Stops before changing any standby. |
| T-034 | Network failure | Block primary-to-one-standby replication path | Affected standby fails verification; healthy standbys are reported separately. |
| T-035 | Restart validation | Restart primary and one standby | Recovered standby returns to healthy sync state within the configured timeout. |

## Cleanup

| ID | Scenario | Command / setup | Expected result |
| --- | --- | --- | --- |
| T-040 | Confirmation required | `./yinstall.sh clean standby --primary 10.0.0.11 -t 10.0.0.12 --standby-remove-cmd 'remove {standby}'` | Non-zero exit; no state changes. |
| T-041 | Cleanup precheck | Add `--precheck` | Lists service, config, and data paths; no changes. |
| T-042 | Remove one standby | `./yinstall.sh clean standby --primary 10.0.0.11 -t 10.0.0.12 --standby-remove-cmd 'remove {standby}' --confirm` | Primary relationship is removed first; target service/config are removed; data remains. |
| T-043 | Purge guard | Run cleanup with only `--purge-data` or only `--confirm` | Non-zero exit; data directory remains. |
| T-044 | Purge data | Use `--purge-data --confirm` after T-042 | Only validated YashanDB data paths are deleted. |
| T-045 | Full topology cleanup | Clean primary and all standbys with explicit topology and confirmation | Services and managed files are removed on all named hosts; unrelated files remain. |

## Automation Gate

Run static checks before VM tests:

```bash
tests/test_cli.sh
shfmt -d yinstall.sh lib/*.sh steps/*.sh
shellcheck yinstall.sh lib/*.sh steps/*.sh
bats tests
```

The release gate passes only when static checks, non-destructive tests, and a
fresh one-primary/two-standby VM deployment and cleanup all pass.
