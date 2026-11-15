# AppControl v1.24.3 — release qualification report

Generated: 2026-11-15T09:33:58.381312+00:00
Source commit: `7c642c5f15400f1dc7a7b7af93c246d21c347561`
Release: https://github.com/xcomponent/appcontrol-release/releases/tag/vv1.24.3

## Scope and result

PASS: the checks listed below completed for this commit and these immutable image digests. This is dated technical qualification, not certification for every production environment or a guarantee of absence of undiscovered vulnerabilities.

The OpenShift client kit targets Linux amd64. Its five images are backend, frontend, gateway, PostgreSQL and the optional test agent. Certificate initialization and Azure gateway are additional release images.

## Vulnerability scans and inventories

Trivy 0.76.1 scans OS and application packages at all severities (UNKNOWN, LOW, MEDIUM, HIGH, CRITICAL), including unfixed advisories. Image scans use comprehensive detection. A scan with missing inventory, known vulnerabilities or suppressed findings fails the release. Each image has its own CycloneDX SBOM. The locked Rust and npm dependencies have an additional SBOM including development dependencies.
Source vulnerability database updated: 2026-11-15T07:02:44.492376642Z. Per-image scanner metadata records the database used for that scan.

| Image | Qualified image and digest | Findings | Scan timestamp |
|---|---|---:|---|
| backend | `appcontrol-backend@sha256:4b772a09908674688b7515fe7e81c31f4acf24edfd16436f956c39e7f263e7cb` | 0 | 2026-11-15T09:10:47.798767277Z |
| frontend | `appcontrol-frontend@sha256:06f3e4d157492204e7082aaf69f5188affdf46df6bd8d149b8c4efdd296c7994` | 0 | 2026-11-15T09:10:48.485393704Z |
| gateway | `appcontrol-gateway@sha256:ed8674402e8a47a6e20358a7d624611323faf76d580014815e82c549feda1d42` | 0 | 2026-11-15T09:10:43.846226314Z |
| agent | `appcontrol-agent@sha256:06a1d72a3adf83e07a4b3bb49a2e9c2508f833c28f88072693dd8d6b261452e2` | 0 | 2026-11-15T09:10:55.624831011Z |
| postgresql | `appcontrol-postgresql@sha256:1eabb2d85389246ab25c71f0e9a0b7fe819d7747d80edb84629c2a387a46fb02` | 0 | 2026-11-15T09:10:57.557635138Z |
| init-certs | `appcontrol-init-certs@sha256:352e4e7378808c79109013826123615dab1e04db7bf57b8fe2548e6e087bde98` | 0 | 2026-11-15T09:10:44.593432025Z |
| azure-gateway | `appcontrol-azure-gateway@sha256:c98b2ceb176acbab807f999890ee01b0fa4f907e98be4e9071c5183d52d743b6` | 0 | 2026-11-15T09:10:57.119244447Z |

| Dependency scope | Inputs | Findings | Scan timestamp |
|---|---|---:|---|
| Production dependencies | Cargo.lock + frontend/package-lock.json | 0 | 2026-11-15T08:34:06.412320763Z |
| Production and development dependencies | Cargo.lock + frontend/package-lock.json | 0 | 2026-11-15T08:34:19.348075244Z |

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
