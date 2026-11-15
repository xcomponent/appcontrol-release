# AppControl v1.24.4 — release qualification report

Generated: 2026-11-15T16:36:10.730492+00:00
Source commit: `383edfe3a36dc7c5c51167c693d70530acd079f1`
Release: https://github.com/xcomponent/appcontrol-release/releases/tag/vv1.24.4

## Scope and result

PASS: the checks listed below completed for this commit and these immutable image digests. This is dated technical qualification, not certification for every production environment or a guarantee of absence of undiscovered vulnerabilities.

The OpenShift client kit targets Linux amd64. Its five images are backend, frontend, gateway, PostgreSQL and the optional test agent. Certificate initialization and Azure gateway are additional release images.

## Vulnerability scans and inventories

Trivy 0.76.1 scans OS and application packages at all severities (UNKNOWN, LOW, MEDIUM, HIGH, CRITICAL), including unfixed advisories. Image scans use comprehensive detection. A scan with missing inventory, known vulnerabilities or suppressed findings fails the release. Each image has its own CycloneDX SBOM. The locked Rust and npm dependencies have an additional SBOM including development dependencies.
Source vulnerability database updated: 2026-11-15T12:50:30.599818283Z. Per-image scanner metadata records the database used for that scan.

| Image | Qualified image and digest | Findings | Scan timestamp |
|---|---|---:|---|
| backend | `appcontrol-backend@sha256:c4dafac0667b68992e48393800484b7da0e4e3c33b36ec16f9de0ea8d2302ec0` | 0 | 2026-11-15T16:24:15.088773534Z |
| frontend | `appcontrol-frontend@sha256:29c4f4285ac5de0e4bfacdc02e0939ef0c627cccb24a89c3baa62402b4ba083d` | 0 | 2026-11-15T16:24:17.37337963Z |
| gateway | `appcontrol-gateway@sha256:9bc08a485b4fa54a6d6fc5ab239c71fda4e6b0d88b2eae02a106651b86d099b5` | 0 | 2026-11-15T16:24:10.568864445Z |
| agent | `appcontrol-agent@sha256:820d9957b94e3b18fec36276b267a9ef34c51742a7bb2437332d47bf123b2804` | 0 | 2026-11-15T16:24:09.837646974Z |
| postgresql | `appcontrol-postgresql@sha256:44b6a3112fdebb83e030b09de1f66cde06974a1ed16b170f25c894dcced6492a` | 0 | 2026-11-15T16:24:18.756155645Z |
| init-certs | `appcontrol-init-certs@sha256:1a1e79422312b6ff92faff32f611f0709b6da9ce4d486b05b960f4011d4f1459` | 0 | 2026-11-15T16:24:03.271666834Z |
| azure-gateway | `appcontrol-azure-gateway@sha256:b0cb110aa4d67b9df47b3db97058076e3259310e618b9a2f1a74ae01517ca7e9` | 0 | 2026-11-15T16:24:11.252824175Z |

| Dependency scope | Inputs | Findings | Scan timestamp |
|---|---|---:|---|
| Production dependencies | Cargo.lock + frontend/package-lock.json | 0 | 2026-11-15T16:04:47.491771937Z |
| Production and development dependencies | Cargo.lock + frontend/package-lock.json | 0 | 2026-11-15T16:05:00.774936887Z |

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
