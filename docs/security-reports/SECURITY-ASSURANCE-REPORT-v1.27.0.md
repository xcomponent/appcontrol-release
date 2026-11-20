# AppControl v1.27.0 — release qualification report

Generated: 2026-11-20T20:55:19.244643+00:00
Source commit: `e9eafd55b45d7aa29308da845c0e755e5de4e547`
Release: https://github.com/xcomponent/appcontrol-release/releases/tag/vv1.27.0

## Scope and result

PASS: the checks listed below completed for this commit and these immutable image digests. This is dated technical qualification, not certification for every production environment or a guarantee of absence of undiscovered vulnerabilities.

The OpenShift client kit targets Linux amd64. Its five images are backend, frontend, gateway, PostgreSQL and the optional test agent. Certificate initialization and Azure gateway are additional release images.

## Vulnerability scans and inventories

Trivy 0.76.1 scans OS and application packages at all severities (UNKNOWN, LOW, MEDIUM, HIGH, CRITICAL), including unfixed advisories. Image scans use comprehensive detection. A scan with missing inventory, unresolved vulnerabilities or suppressed findings fails the release. Each image has its own CycloneDX SBOM. The locked Rust and npm dependencies have an additional SBOM including development dependencies.
Source vulnerability database updated: 2026-11-20T13:11:33.075919767Z. Per-image scanner metadata records the database used for that scan.

| Image | Qualified image and digest | Findings | Scan timestamp |
|---|---|---:|---|
| backend | `appcontrol-backend@sha256:07928dac6e70d55046d80ce1b34cbec59e79f6b58bde37b947f677520838c41a` | 0 | 2026-11-20T20:23:17.3105361Z |
| frontend | `appcontrol-frontend@sha256:7b63ac81fc59a8d5618fd548002bbe7bd566d7ae799a81a9253e812bd88299a9` | 0 | 2026-11-20T20:23:28.890812382Z |
| gateway | `appcontrol-gateway@sha256:31ecde4a6b18cb7c2934d8ec496d00fafb9abed730038f720ec22176d6215596` | 0 | 2026-11-20T20:23:23.149478267Z |
| agent | `appcontrol-agent@sha256:f73ba69fe0bf1c2fe5e36bfd8df673d5b1dc93a14f6f049e566a059304452642` | 0 | 2026-11-20T20:23:15.105744994Z |
| postgresql | `appcontrol-postgresql@sha256:8c6ba094a3e12d319153e9594586f41c8bad19645dca78583e805f135ca54fab` | 0 | 2026-11-20T20:23:22.920564942Z |
| init-certs | `appcontrol-init-certs@sha256:62f9bce9724118ac240cd62f717efd0732068ea5c53e76df05bd3daec0e57d10` | 0 | 2026-11-20T20:23:23.373216848Z |
| azure-gateway | `appcontrol-azure-gateway@sha256:1e206756974cd48e6fa4b368e88902ad2a9ae3f236cc490a4468f66f6fb42507` | 0 | 2026-11-20T20:23:24.305842684Z |

| Dependency scope | Inputs | Unresolved findings | Scan timestamp |
|---|---|---:|---|
| Production dependencies | Cargo.lock + frontend/package-lock.json | 0 | 2026-11-20T19:56:45.518991059Z |
| Production and development dependencies | Cargo.lock + frontend/package-lock.json | 0 | 2026-11-20T19:56:58.993729047Z |

RustSec: zero vulnerability advisories. Informational warnings, if any, remain in rustsec.json and are not reclassified as vulnerabilities.
RustSec warning categories: unmaintained: 4, unsound: 1, yanked: 1.

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
