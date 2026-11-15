# AppControl v1.24.5 — release qualification report

Generated: 2026-11-15T23:46:36.837846+00:00
Source commit: `db3b4123e1071bbc2d52171b6b3bde679c1f568f`
Release: https://github.com/xcomponent/appcontrol-release/releases/tag/vv1.24.5

## Scope and result

PASS: the checks listed below completed for this commit and these immutable image digests. This is dated technical qualification, not certification for every production environment or a guarantee of absence of undiscovered vulnerabilities.

The OpenShift client kit targets Linux amd64. Its five images are backend, frontend, gateway, PostgreSQL and the optional test agent. Certificate initialization and Azure gateway are additional release images.

## Vulnerability scans and inventories

Trivy 0.76.1 scans OS and application packages at all severities (UNKNOWN, LOW, MEDIUM, HIGH, CRITICAL), including unfixed advisories. Image scans use comprehensive detection. A scan with missing inventory, known vulnerabilities or suppressed findings fails the release. Each image has its own CycloneDX SBOM. The locked Rust and npm dependencies have an additional SBOM including development dependencies.
Source vulnerability database updated: 2026-11-15T18:56:37.733847835Z. Per-image scanner metadata records the database used for that scan.

| Image | Qualified image and digest | Findings | Scan timestamp |
|---|---|---:|---|
| backend | `appcontrol-backend@sha256:ca89ac06637837fc33f37371009c97a79af559ce6f799fa294db7fd2b27d7449` | 0 | 2026-11-15T23:34:36.191386417Z |
| frontend | `appcontrol-frontend@sha256:3d146ef63e2ec366631cd1993b14a7ce55f692bda1d3a2e3e0a366b47dd171c0` | 0 | 2026-11-15T23:34:34.062416509Z |
| gateway | `appcontrol-gateway@sha256:4094d8845306debc481457c082ee314c7890effc60ef824fa33f874fff3f2186` | 0 | 2026-11-15T23:34:39.978810957Z |
| agent | `appcontrol-agent@sha256:37fd4a7e8490b4ad67fcbf0d2653460a65ad40a84022fb258db9d20477e31510` | 0 | 2026-11-15T23:34:31.873281414Z |
| postgresql | `appcontrol-postgresql@sha256:aba4b226e7e19419e2fc9969e30c051b5b3010ae199010c81e20ce76a8048c80` | 0 | 2026-11-15T23:34:32.899136014Z |
| init-certs | `appcontrol-init-certs@sha256:1369c93cf1ad08574084a1d29db8e70c20032eaf4656ca4c55dbb477bafe27b7` | 0 | 2026-11-15T23:34:38.490053502Z |
| azure-gateway | `appcontrol-azure-gateway@sha256:5da4e4af30740fafbe39787696f0d8ace58ce41d071dd0b30302b66c0b81744f` | 0 | 2026-11-15T23:34:45.773731982Z |

| Dependency scope | Inputs | Findings | Scan timestamp |
|---|---|---:|---|
| Production dependencies | Cargo.lock + frontend/package-lock.json | 0 | 2026-11-15T23:15:19.597979961Z |
| Production and development dependencies | Cargo.lock + frontend/package-lock.json | 0 | 2026-11-15T23:15:31.870819045Z |

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
