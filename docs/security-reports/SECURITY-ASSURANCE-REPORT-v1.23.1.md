# AppControl v1.23.1 — release qualification report

Generated: 2026-11-11T18:40:40.703546+00:00
Source commit: `3cfc094fe33acc87a2b4f188456fdd3d8c1ec0f0`
Release workflow: https://github.com/fredericcarre/appcontrol/actions/runs/43071954669

## Scope and result

PASS: the checks listed below completed for this commit and these immutable image digests. This is dated technical qualification, not certification for every production environment or a guarantee of absence of undiscovered vulnerabilities.

The OpenShift client kit targets Linux amd64. Its five images are backend, frontend, gateway, PostgreSQL and the optional test agent. Certificate initialization and Azure gateway are additional release images.

## Vulnerability scans and inventories

Trivy 0.76.1 scans OS and application packages at all severities (UNKNOWN, LOW, MEDIUM, HIGH, CRITICAL), including unfixed advisories. Image scans use comprehensive detection. A scan with missing inventory, known vulnerabilities or suppressed findings fails the release. Each image has its own CycloneDX SBOM. The locked Rust and npm dependencies have an additional SBOM including development dependencies.
Source vulnerability database updated: 2026-11-11T13:00:47.186797699Z. Per-image scanner metadata records the database used for that scan.

| Image | Delivered immutable reference | Findings | Scan timestamp |
|---|---|---:|---|
| backend | `ghcr.io/fredericcarre/appcontrol-backend@sha256:bff2a1700a3d717ce6c9fe0b3a99e38dcf8eeaf302865b40c60f15b9955b8ce3` | 0 | 2026-11-11T18:27:49.782657336Z |
| frontend | `ghcr.io/fredericcarre/appcontrol-frontend@sha256:5a562c8f84c00139c501f09631be9b9e4c34d68063664513c9ea3d125d4c9532` | 0 | 2026-11-11T18:27:54.572970567Z |
| gateway | `ghcr.io/fredericcarre/appcontrol-gateway@sha256:bb2cb9acfaa8fcd086da69c64abf78569881216a1c8d5fa5249f529ff23ce906` | 0 | 2026-11-11T18:27:56.230661909Z |
| agent | `ghcr.io/fredericcarre/appcontrol-agent@sha256:85446a778d1ab65611c286f81ab88e07e70c27cbe95dabc728ed5131769264ff` | 0 | 2026-11-11T18:27:51.419086379Z |
| postgresql | `ghcr.io/fredericcarre/appcontrol-postgresql@sha256:8e392b4ac772e1d7f1ead4600c2e7c82b15cd7cd88ef0629ec79d077cb605862` | 0 | 2026-11-11T18:27:58.713265911Z |
| init-certs | `ghcr.io/fredericcarre/appcontrol-init-certs@sha256:564a6b273aac3876cd75e49d214961f5cffba1b22d0e6a4f5edcd95ce455bbb5` | 0 | 2026-11-11T18:27:53.863416795Z |
| azure-gateway | `ghcr.io/fredericcarre/appcontrol-azure-gateway@sha256:ad3a9ec380ad167a92665b53f5261b03ff158f45cd2ceec83c72297b063b47de` | 0 | 2026-11-11T18:27:56.266176088Z |

| Dependency scope | Inputs | Findings | Scan timestamp |
|---|---|---:|---|
| Production dependencies | Cargo.lock + frontend/package-lock.json | 0 | 2026-11-11T17:51:09.280320289Z |
| Production and development dependencies | Cargo.lock + frontend/package-lock.json | 0 | 2026-11-11T17:51:22.102433376Z |

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
