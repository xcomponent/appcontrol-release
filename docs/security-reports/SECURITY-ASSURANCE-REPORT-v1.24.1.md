# AppControl v1.24.1 — release qualification report

Generated: 2026-11-12T23:21:15.677149+00:00
Source commit: `4d56a844b1b4efd925c2794c18c556c5a1dd3db7`
Release workflow: https://github.com/xcomponent/appcontrol-release/releases

## Scope and result

PASS: the checks listed below completed for this commit and these immutable image digests. This is dated technical qualification, not certification for every production environment or a guarantee of absence of undiscovered vulnerabilities.

The OpenShift client kit targets Linux amd64. Its five images are backend, frontend, gateway, PostgreSQL and the optional test agent. Certificate initialization and Azure gateway are additional release images.

## Vulnerability scans and inventories

Trivy 0.76.1 scans OS and application packages at all severities (UNKNOWN, LOW, MEDIUM, HIGH, CRITICAL), including unfixed advisories. Image scans use comprehensive detection. A scan with missing inventory, known vulnerabilities or suppressed findings fails the release. Each image has its own CycloneDX SBOM. The locked Rust and npm dependencies have an additional SBOM including development dependencies.
Source vulnerability database updated: 2026-11-12T18:57:38.498853214Z. Per-image scanner metadata records the database used for that scan.

| Image | Delivered immutable reference | Findings | Scan timestamp |
|---|---|---:|---|
| backend | `appcontrol-backend@sha256:1e78baf0002af142cbdba6a57ee4703643477d980e208917bca5fc85bbe2a37d` | 0 | 2026-11-12T23:05:28.871559135Z |
| frontend | `appcontrol-frontend@sha256:9c6f432d8eee861dd9b58298d8d0b6fa408112d604a84a1ea263d8b3677b2174` | 0 | 2026-11-12T23:05:36.286395779Z |
| gateway | `appcontrol-gateway@sha256:433b8612a1de429003da95c9bd5aaa6c0e4bb05db97877e6a2566cd087077236` | 0 | 2026-11-12T23:05:32.615164795Z |
| agent | `appcontrol-agent@sha256:92a4b838c1edb70d5be900e1ce08db1293405ed224fa8cf7a6833406457f5534` | 0 | 2026-11-12T23:05:33.943443564Z |
| postgresql | `appcontrol-postgresql@sha256:98c940a895a9dc13c22b3ec95f0a5368801c0391a66480a521ed7548a29be90a` | 0 | 2026-11-12T23:05:35.574809154Z |
| init-certs | `appcontrol-init-certs@sha256:13ce79ced59562307eb09b695ffcd74d0bcf0401ad43d3fd03879d452e45b08c` | 0 | 2026-11-12T23:05:30.135243203Z |
| azure-gateway | `appcontrol-azure-gateway@sha256:76cdbfbda363d348bea0345e2f3e32bfdccfb41efffd667ec8498bb57ea514bd` | 0 | 2026-11-12T23:05:39.095854304Z |

| Dependency scope | Inputs | Findings | Scan timestamp |
|---|---|---:|---|
| Production dependencies | Cargo.lock + frontend/package-lock.json | 0 | 2026-11-12T22:17:09.893167544Z |
| Production and development dependencies | Cargo.lock + frontend/package-lock.json | 0 | 2026-11-12T22:17:21.871669284Z |

RustSec: zero vulnerability advisories. Informational warnings, if any, remain in rustsec.json and are not reclassified as vulnerabilities.
RustSec warning categories: unmaintained: 2, unsound: 1, yanked: 1.

## Executed checks

| Check | Result and scope |
|---|---|
| Rust formatting, Clippy and unit tests | Passed on the delivered source; PostgreSQL test service |
| Frontend lint, unit tests and production build | Passed; the same static artifact is packaged into the frontend image and ZIP |
| Docker Compose | Passed gateway/agent/command cycle using digest-locked release images. Test HTTPS uses a local self-signed certificate with verification disabled; this does not qualify TLS trust |
| OpenShift | Passed actual installation, public HTTPS Routes, restricted SCC assertions, enrollment, command ordering and persistence checks recorded below |
| Windows Server/PostgreSQL package | Passed installation, service health and administrative operations on the GitHub Windows runner; not a qualification of every customer Windows Server policy |

- Verified HTTPS login
- Anonymous application access denied
- Agent enrollment through verified TLS gateway and backend mTLS
- Public reencrypt frontend Route, passthrough agent Route and restricted SCC admission
- Read-only application key can read but cannot execute start
- Real commands: dependency starts before its consumer
- Real commands: consumer stops before its dependency
- Gateway restart reconnects and still executes commands
- Map persists after backend restart
- Map persists and backend reconnects after PostgreSQL restart

## Limits

The other native-platform binaries and SQLite variants are built but are not assigned an end-to-end PASS by this workflow. Azure gateway is scanned but Azure deployment is not exercised. GitHub runner databases, demo seeders and the Compose reverse proxy are test infrastructure outside the delivered OpenShift image set. Customer network policies, registry approval, backups, HA, identity federation and operational procedures require environment-specific validation.

Only a stable tag may promote latest and publish the customer release. RC tags remain prereleases. Official publication also requires successful assembly of the offline kit after this report is generated.

Raw JSON reports, scanner/database metadata, SBOMs, job conclusions, source checksums, image lock and real-cluster evidence accompany this report.
