# AppControl v1.21.1 — release qualification report

Generated: 2026-11-03T12:09:15.500172+00:00
Source commit: `c82f61c89ea9429166785702475b5cea9b7ed8bf`
Release workflow: https://github.com/fredericcarre/appcontrol/actions/runs/41625978777

## Scope and result

PASS: the checks listed below completed for this commit and these immutable image digests. This is dated technical qualification, not certification for every production environment or a guarantee of absence of undiscovered vulnerabilities.

The OpenShift client kit targets Linux amd64. Its five images are backend, frontend, gateway, PostgreSQL and the optional test agent. Certificate initialization and Azure gateway are additional release images.

## Vulnerability scans and inventories

Trivy 0.76.1 scans OS and application packages at all severities (UNKNOWN, LOW, MEDIUM, HIGH, CRITICAL), including unfixed advisories. No ignore file, vulnerability suppression or severity exclusion is used. Each image has its own CycloneDX SBOM; locked Rust and npm dependencies have an additional SBOM including development dependencies.
Source vulnerability database updated: 2026-11-03T07:14:02.629452927Z. Per-image scanner metadata records the database used for that scan.

| Image | Delivered immutable reference | Findings | Scan timestamp |
|---|---|---:|---|
| backend | `ghcr.io/fredericcarre/appcontrol-backend@sha256:2661efa31fef6ce0c5e1d006bcbacd7893251cb37a5cc0ee5f9b4465b624b94d` | 0 | 2026-11-03T12:00:19.139053151Z |
| frontend | `ghcr.io/fredericcarre/appcontrol-frontend@sha256:c7eebab2b6ebbee825b699f45c9a1089ae42459ad5894600ef806acabe64980a` | 0 | 2026-11-03T12:00:14.722016985Z |
| gateway | `ghcr.io/fredericcarre/appcontrol-gateway@sha256:fa36849338cbcd9b4998b8ac4caffd11c6c1b9ae41b78c7f178509e328fce312` | 0 | 2026-11-03T12:00:13.297772134Z |
| agent | `ghcr.io/fredericcarre/appcontrol-agent@sha256:85e9ed5ecce7530fe1217ff55b4d501605e4e2f79a41da4ba7a6eb391dd2fa61` | 0 | 2026-11-03T12:00:15.979693536Z |
| postgresql | `ghcr.io/fredericcarre/appcontrol-postgresql@sha256:0f70cc13e4dd5c2349c4533cadb2bccd76179824d78f2352c64d9e0c3c4abeea` | 0 | 2026-11-03T12:00:33.330985975Z |
| init-certs | `ghcr.io/fredericcarre/appcontrol-init-certs@sha256:a19b15b903118366896f3f6b15ab93f39e0b4c2170b777f984dd1c0b7a3ad5cf` | 0 | 2026-11-03T12:00:15.627228118Z |
| azure-gateway | `ghcr.io/fredericcarre/appcontrol-azure-gateway@sha256:faef4fd4d4a8a453ef0d1cdd11877cb001c828dcfed94c688362fa6b815415b0` | 0 | 2026-11-03T12:00:25.890112518Z |

| Dependency scope | Inputs | Findings | Scan timestamp |
|---|---|---:|---|
| Production dependencies | Cargo.lock + frontend/package-lock.json | 0 | 2026-11-03T11:15:46.788762718Z |
| Production and development dependencies | Cargo.lock + frontend/package-lock.json | 0 | 2026-11-03T11:16:00.058479906Z |

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
