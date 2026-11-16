# AppControl v1.24.6 — release qualification report

Generated: 2026-11-16T07:36:19.287245+00:00
Source commit: `304683825ca5fe47904c97ba57d975556faa5cb1`
Release: https://github.com/xcomponent/appcontrol-release/releases/tag/vv1.24.6

## Scope and result

PASS: the checks listed below completed for this commit and these immutable image digests. This is dated technical qualification, not certification for every production environment or a guarantee of absence of undiscovered vulnerabilities.

The OpenShift client kit targets Linux amd64. Its five images are backend, frontend, gateway, PostgreSQL and the optional test agent. Certificate initialization and Azure gateway are additional release images.

## Vulnerability scans and inventories

Trivy 0.76.1 scans OS and application packages at all severities (UNKNOWN, LOW, MEDIUM, HIGH, CRITICAL), including unfixed advisories. Image scans use comprehensive detection. A scan with missing inventory, known vulnerabilities or suppressed findings fails the release. Each image has its own CycloneDX SBOM. The locked Rust and npm dependencies have an additional SBOM including development dependencies.
Source vulnerability database updated: 2026-11-16T01:11:02.624123452Z. Per-image scanner metadata records the database used for that scan.

| Image | Qualified image and digest | Findings | Scan timestamp |
|---|---|---:|---|
| backend | `appcontrol-backend@sha256:1a21ff8a8d5fac9c7b05829c24b9b8f10b4813f13685eb1e8336705d9e38c527` | 0 | 2026-11-16T06:30:04.73877202Z |
| frontend | `appcontrol-frontend@sha256:c02cdf8b2b90d23a2ff4c64f99e3b14f8dddf7cbd75ccb0005c1651f911aae80` | 0 | 2026-11-16T06:30:05.706341921Z |
| gateway | `appcontrol-gateway@sha256:ae03c7e04bef0fdce8e1e3776e8336662ff0c0f4ac3b6817a0929f6c58f0c212` | 0 | 2026-11-16T06:30:03.932315875Z |
| agent | `appcontrol-agent@sha256:4c47e6f0e386afdd5fb1b38592bd53b187d72c15c82752f5c675a4c50f268a8f` | 0 | 2026-11-16T06:30:01.354632397Z |
| postgresql | `appcontrol-postgresql@sha256:d1d9e6af927fe79662a26c5961a8cfe922f15505a210e519d6235a0b07c93c95` | 0 | 2026-11-16T06:29:58.731871679Z |
| init-certs | `appcontrol-init-certs@sha256:153ce8b0bd8ceb1015436b4b9d706d118a29db12ef236884124be36a877d9802` | 0 | 2026-11-16T06:30:01.502122203Z |
| azure-gateway | `appcontrol-azure-gateway@sha256:6a26d6776819f0a012eaa916077bfdb618d54ddcc17174e922d148fcdbb9bf15` | 0 | 2026-11-16T06:30:10.603237432Z |

| Dependency scope | Inputs | Findings | Scan timestamp |
|---|---|---:|---|
| Production dependencies | Cargo.lock + frontend/package-lock.json | 0 | 2026-11-16T06:05:04.073179934Z |
| Production and development dependencies | Cargo.lock + frontend/package-lock.json | 0 | 2026-11-16T06:05:09.770498043Z |

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
