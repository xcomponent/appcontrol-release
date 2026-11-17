# AppControl v1.24.9 — release qualification report

Generated: 2026-11-17T06:10:26.527695+00:00
Source commit: `4ae2617e77fc871fc8d86d49df0d37c4c22455cc`
Release: https://github.com/xcomponent/appcontrol-release/releases/tag/vv1.24.9

## Scope and result

PASS: the checks listed below completed for this commit and these immutable image digests. This is dated technical qualification, not certification for every production environment or a guarantee of absence of undiscovered vulnerabilities.

The OpenShift client kit targets Linux amd64. Its five images are backend, frontend, gateway, PostgreSQL and the optional test agent. Certificate initialization and Azure gateway are additional release images.

## Vulnerability scans and inventories

Trivy 0.76.1 scans OS and application packages at all severities (UNKNOWN, LOW, MEDIUM, HIGH, CRITICAL), including unfixed advisories. Image scans use comprehensive detection. A scan with missing inventory, known vulnerabilities or suppressed findings fails the release. Each image has its own CycloneDX SBOM. The locked Rust and npm dependencies have an additional SBOM including development dependencies.
Source vulnerability database updated: 2026-11-16T18:50:18.311537747Z. Per-image scanner metadata records the database used for that scan.

| Image | Qualified image and digest | Findings | Scan timestamp |
|---|---|---:|---|
| backend | `appcontrol-backend@sha256:37a8cb129280a96d1decdee95d0c0c7fa2a21f5a974e465269aecc7db539cd2a` | 0 | 2026-11-17T06:02:59.080344292Z |
| frontend | `appcontrol-frontend@sha256:bd9059138acc90ec83bf2100a4f35e2eac5b5c03105f1731198ab1b79f80c1e6` | 0 | 2026-11-17T06:02:55.862886585Z |
| gateway | `appcontrol-gateway@sha256:fde95c7901daf375b2806ee61c2cedc572fba339b38f01e356f9b5abc188103e` | 0 | 2026-11-17T06:02:56.375193917Z |
| agent | `appcontrol-agent@sha256:e3f9a43710a9678b05f01c7eb778e586eabfa2ae40315daacdce2bed71c43054` | 0 | 2026-11-17T06:02:57.527351363Z |
| postgresql | `appcontrol-postgresql@sha256:c1f63ec5f6b4e3a1ff76e55dc04cfa420081440ce44063b40438a7ba48bac871` | 0 | 2026-11-17T06:03:04.466524296Z |
| init-certs | `appcontrol-init-certs@sha256:2094ea60650ed67cf16e1835103a0510f8af38c849a1ca02103bb237fd18037e` | 0 | 2026-11-17T06:02:57.996814052Z |
| azure-gateway | `appcontrol-azure-gateway@sha256:8e50d4e20b22cf58b5fcd2e06c0b6b11f5228321685524d34ac5ac36a6f90e2a` | 0 | 2026-11-17T06:03:00.021609702Z |

| Dependency scope | Inputs | Findings | Scan timestamp |
|---|---|---:|---|
| Production dependencies | Cargo.lock + frontend/package-lock.json | 0 | 2026-11-16T23:29:31.289585482Z |
| Production and development dependencies | Cargo.lock + frontend/package-lock.json | 0 | 2026-11-16T23:29:44.555999993Z |

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
