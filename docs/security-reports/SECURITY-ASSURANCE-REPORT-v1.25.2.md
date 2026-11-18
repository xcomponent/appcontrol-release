# AppControl v1.25.2 — release qualification report

Generated: 2026-11-18T10:37:03.295350+00:00
Source commit: `c30b0ee95405c250d794d1ebd8f2a4d0452c4a6c`
Release: https://github.com/xcomponent/appcontrol-release/releases/tag/vv1.25.2

## Scope and result

PASS: the checks listed below completed for this commit and these immutable image digests. This is dated technical qualification, not certification for every production environment or a guarantee of absence of undiscovered vulnerabilities.

The OpenShift client kit targets Linux amd64. Its five images are backend, frontend, gateway, PostgreSQL and the optional test agent. Certificate initialization and Azure gateway are additional release images.

## Vulnerability scans and inventories

Trivy 0.76.1 scans OS and application packages at all severities (UNKNOWN, LOW, MEDIUM, HIGH, CRITICAL), including unfixed advisories. Image scans use comprehensive detection. A scan with missing inventory, unresolved vulnerabilities or suppressed findings fails the release. Each image has its own CycloneDX SBOM. The locked Rust and npm dependencies have an additional SBOM including development dependencies.
Source vulnerability database updated: 2026-11-18T07:15:21.579242117Z. Per-image scanner metadata records the database used for that scan.

| Image | Qualified image and digest | Findings | Scan timestamp |
|---|---|---:|---|
| backend | `appcontrol-backend@sha256:7b2713c6235697387d618c4b90003abfd2f6b33bffea7501c7f69c1dcab8da40` | 0 | 2026-11-18T09:52:40.407194445Z |
| frontend | `appcontrol-frontend@sha256:7cb0dfc055f71fb5a7bcd059eb77afbc397847ae5e1bb0667f0de8c6429b3f86` | 0 | 2026-11-18T09:52:39.35552805Z |
| gateway | `appcontrol-gateway@sha256:dbaa816e56e14a44f332007465c0fe8aa38fa1f97733aea1494986082c352466` | 0 | 2026-11-18T09:52:41.645446194Z |
| agent | `appcontrol-agent@sha256:24bd45211eb6c2cca0c7ea38fcdffdbfb1d50505bc45ccbb2a2a01848186e906` | 0 | 2026-11-18T09:52:46.480226357Z |
| postgresql | `appcontrol-postgresql@sha256:d0166cbced561956065265e63bfd09473e2e93e4aa049056ce98c71b2fad3c02` | 0 | 2026-11-18T09:52:44.062351972Z |
| init-certs | `appcontrol-init-certs@sha256:646a2735491310de2257b7c3a7ecdfafe931abd67a7ef5b4bf5560f3258f62ae` | 0 | 2026-11-18T09:52:31.032577283Z |
| azure-gateway | `appcontrol-azure-gateway@sha256:99a1ba686dc98b248a4ef3f3075b851c046c927a7283006f28de40956a554afe` | 0 | 2026-11-18T09:52:39.815847571Z |

| Dependency scope | Inputs | Unresolved findings | Scan timestamp |
|---|---|---:|---|
| Production dependencies | Cargo.lock + frontend/package-lock.json | 0 | 2026-11-18T09:26:41.468894459Z |
| Production and development dependencies | Cargo.lock + frontend/package-lock.json | 0 | 2026-11-18T09:26:45.67268414Z |

The raw development scan flags the upstream version numbers below. X4B verifies that all installed copies use the local archives that remove the affected syntax. These archives are used by frontend build and test tooling.
- `picomatch@2.3.2` — `CVE-2026-112366`, verified local mitigation.
- `picomatch@4.0.7` — `CVE-2026-112366`, verified local mitigation.

The local patches, upstream references and archive checksums are included in `picomatch-backport/`.

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
