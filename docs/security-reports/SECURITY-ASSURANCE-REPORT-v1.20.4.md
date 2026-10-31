# AppControl v1.20.4 — release qualification report

Generated: 2026-10-31T08:38:01.979339+00:00
Source commit: `15c5be2ca7cd43647748c7e4227123051342291d`
Release workflow: https://github.com/fredericcarre/appcontrol/actions/runs/40698656946

## Scope and result

PASS: the checks listed below completed for this commit and these immutable image digests. This is dated technical qualification, not certification for every production environment or a guarantee of absence of undiscovered vulnerabilities.

The OpenShift client kit targets Linux amd64. Its five images are backend, frontend, gateway, PostgreSQL and the optional test agent. Certificate initialization and Azure gateway are additional release images.

## Vulnerability scans and inventories

Trivy 0.76.1 scans OS and application packages at all severities (UNKNOWN, LOW, MEDIUM, HIGH, CRITICAL), including unfixed advisories. No ignore file, vulnerability suppression or severity exclusion is used. Each image has its own CycloneDX SBOM; locked Rust and npm dependencies have an additional SBOM including development dependencies.
Source vulnerability database updated: 2026-10-28T07:10:42.861393948Z. Per-image scanner metadata records the database used for that scan.

| Image | Delivered immutable reference | Findings | Scan timestamp |
|---|---|---:|---|
| backend | `ghcr.io/fredericcarre/appcontrol-backend@sha256:dc23b2d93e01f176bbfe2679eedbf57551a9bbf58008de8784c07247e4b3284b` | 0 | 2026-10-31T08:24:21.894310745Z |
| frontend | `ghcr.io/fredericcarre/appcontrol-frontend@sha256:2e74458366d05ed7c98b98d8ba7b04cf1159328ec266f7e5a5c86d14c0fc4200` | 0 | 2026-10-31T08:24:14.571781244Z |
| gateway | `ghcr.io/fredericcarre/appcontrol-gateway@sha256:3703d1fee9a0dcac2a8307666ded45b89d992c1278ac1a1352feb0ba84215d75` | 0 | 2026-10-31T08:24:18.264139316Z |
| agent | `ghcr.io/fredericcarre/appcontrol-agent@sha256:031c93e24d73731aca49de234695f9b60f912ae99c4649a23351e31ec31e64ac` | 0 | 2026-10-31T08:24:17.901409428Z |
| postgresql | `ghcr.io/fredericcarre/appcontrol-postgresql@sha256:26fe747e7c3be030755e657ef11634269a1241566c591aec2c165aa05ea8552c` | 0 | 2026-10-31T08:24:22.14136858Z |
| init-certs | `ghcr.io/fredericcarre/appcontrol-init-certs@sha256:dc90cf4582b699c58f2845c339d33c84799635a42c8b9ecd04f9ff06a2ad798b` | 0 | 2026-10-31T08:24:14.090575078Z |
| azure-gateway | `ghcr.io/fredericcarre/appcontrol-azure-gateway@sha256:baec3ddc29cff3e3684e86d3632b70076c1679d3a950f64240ac6a2bb15ea785` | 0 | 2026-10-31T08:24:22.550585618Z |

| Dependency scope | Inputs | Findings | Scan timestamp |
|---|---|---:|---|
| Production dependencies | Cargo.lock + frontend/package-lock.json | 0 | 2026-10-28T13:41:26.042677946Z |
| Production and development dependencies | Cargo.lock + frontend/package-lock.json | 0 | 2026-10-28T13:41:31.107335476Z |

RustSec: zero vulnerability advisories. Informational warnings, if any, remain in rustsec.json and are not reclassified as vulnerabilities.
RustSec warning categories: unmaintained: 2, yanked: 1.

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
