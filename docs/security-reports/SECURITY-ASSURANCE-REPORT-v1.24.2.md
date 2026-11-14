# AppControl v1.24.2 — release qualification report

Generated: 2026-11-14T08:36:47.585270+00:00
Source commit: `34dec78b5f687eae6154a58e1ca5d25c0ac9b33f`
Release: https://github.com/xcomponent/appcontrol-release/releases/tag/vv1.24.2

## Scope and result

PASS: the checks listed below completed for this commit and these immutable image digests. This is dated technical qualification, not certification for every production environment or a guarantee of absence of undiscovered vulnerabilities.

The OpenShift client kit targets Linux amd64. Its five images are backend, frontend, gateway, PostgreSQL and the optional test agent. Certificate initialization and Azure gateway are additional release images.

## Vulnerability scans and inventories

Trivy 0.76.1 scans OS and application packages at all severities (UNKNOWN, LOW, MEDIUM, HIGH, CRITICAL), including unfixed advisories. Image scans use comprehensive detection. A scan with missing inventory, known vulnerabilities or suppressed findings fails the release. Each image has its own CycloneDX SBOM. The locked Rust and npm dependencies have an additional SBOM including development dependencies.
Source vulnerability database updated: 2026-11-14T01:05:40.480840314Z. Per-image scanner metadata records the database used for that scan.

| Image | Qualified image and digest | Findings | Scan timestamp |
|---|---|---:|---|
| backend | `appcontrol-backend@sha256:212b9fa8ff0242d1a8423762cc4372144c2e03a17969cdbe2cb6179b46b6f9a4` | 0 | 2026-11-14T08:20:59.793199031Z |
| frontend | `appcontrol-frontend@sha256:23d9df612b246200f961b9974055eb7b218e8e3e1fa5659e19ae8c45872a4529` | 0 | 2026-11-14T08:20:56.349961918Z |
| gateway | `appcontrol-gateway@sha256:d7ee8e87ca652c4d7e3d63dbcb4b0f581f826b0283357264c7e72ebb28910a7b` | 0 | 2026-11-14T08:20:50.135532382Z |
| agent | `appcontrol-agent@sha256:286240ff3eea7c324999e87ca0d05eea495e081d7fa12e3de93f81498fd88c4b` | 0 | 2026-11-14T08:20:53.27738538Z |
| postgresql | `appcontrol-postgresql@sha256:840e69efdd3e3f4395f3616f4fc26a83456efa88f64bead754206de78477fdfa` | 0 | 2026-11-14T08:20:53.894349881Z |
| init-certs | `appcontrol-init-certs@sha256:c8f07bfa8cb95349102f9f5b571ee8b44e2e3b3e9d01e4718065062b94d81312` | 0 | 2026-11-14T08:20:51.441516079Z |
| azure-gateway | `appcontrol-azure-gateway@sha256:24064f5def2346ca65266afa37b4e6f832b083440f74bbf15f08e3fd4e25997c` | 0 | 2026-11-14T08:20:53.232874193Z |

| Dependency scope | Inputs | Findings | Scan timestamp |
|---|---|---:|---|
| Production dependencies | Cargo.lock + frontend/package-lock.json | 0 | 2026-11-14T07:32:25.117518407Z |
| Production and development dependencies | Cargo.lock + frontend/package-lock.json | 0 | 2026-11-14T07:32:37.230931474Z |

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
