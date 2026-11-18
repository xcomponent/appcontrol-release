# AppControl v1.26.0 — release qualification report

Generated: 2026-11-18T20:09:32.322388+00:00
Source commit: `37e8a956e452dd5ec653dd0842f524340d1abc64`
Release: https://github.com/xcomponent/appcontrol-release/releases/tag/vv1.26.0

## Scope and result

PASS: the checks listed below completed for this commit and these immutable image digests. This is dated technical qualification, not certification for every production environment or a guarantee of absence of undiscovered vulnerabilities.

The OpenShift client kit targets Linux amd64. Its five images are backend, frontend, gateway, PostgreSQL and the optional test agent. Certificate initialization and Azure gateway are additional release images.

## Vulnerability scans and inventories

Trivy 0.76.1 scans OS and application packages at all severities (UNKNOWN, LOW, MEDIUM, HIGH, CRITICAL), including unfixed advisories. Image scans use comprehensive detection. A scan with missing inventory, unresolved vulnerabilities or suppressed findings fails the release. Each image has its own CycloneDX SBOM. The locked Rust and npm dependencies have an additional SBOM including development dependencies.
Source vulnerability database updated: 2026-11-18T13:03:23.615586156Z. Per-image scanner metadata records the database used for that scan.

| Image | Qualified image and digest | Findings | Scan timestamp |
|---|---|---:|---|
| backend | `appcontrol-backend@sha256:2de5a5f88b90a76e3705a49b9ce78c4ab9276df7abe7b6929fd069c907abae8a` | 0 | 2026-11-18T19:35:16.644037325Z |
| frontend | `appcontrol-frontend@sha256:74a60b2a39376cedc2796b28c53d0c074aa67cf750e682b9dd97cab84bcf3cbe` | 0 | 2026-11-18T19:35:16.762202972Z |
| gateway | `appcontrol-gateway@sha256:4933e3122304c02bf4c11a868db5c3be0266a83ac4a57d5ce634609b3876a63b` | 0 | 2026-11-18T19:35:08.981183644Z |
| agent | `appcontrol-agent@sha256:a7971c241c1271f769779c9e886e07e343a4032c8a553f19a63b6f2f0617b722` | 0 | 2026-11-18T19:35:08.705533319Z |
| postgresql | `appcontrol-postgresql@sha256:842feed502626129905960196d6346e35f7aa2e7b37c377803a00dcad102a45f` | 0 | 2026-11-18T19:35:14.394044251Z |
| init-certs | `appcontrol-init-certs@sha256:cd3d197abb63c75cee63e37674692592506c4c1336ed95ce32ba900daa31732d` | 0 | 2026-11-18T19:35:13.96233289Z |
| azure-gateway | `appcontrol-azure-gateway@sha256:347ff1c8552dd3a715c3f594082ff1f77880c07db7c3421b15a6a3beeece8f8d` | 0 | 2026-11-18T19:35:14.724357067Z |

| Dependency scope | Inputs | Unresolved findings | Scan timestamp |
|---|---|---:|---|
| Production dependencies | Cargo.lock + frontend/package-lock.json | 0 | 2026-11-18T19:12:45.124006694Z |
| Production and development dependencies | Cargo.lock + frontend/package-lock.json | 0 | 2026-11-18T19:12:57.076000027Z |

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
