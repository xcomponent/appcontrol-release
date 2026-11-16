# AppControl v1.24.7 — release qualification report

Generated: 2026-11-16T12:20:22.415339+00:00
Source commit: `155019de73a048cefd372f5c83e4120ae67120b3`
Release: https://github.com/xcomponent/appcontrol-release/releases/tag/vv1.24.7

## Scope and result

PASS: the checks listed below completed for this commit and these immutable image digests. This is dated technical qualification, not certification for every production environment or a guarantee of absence of undiscovered vulnerabilities.

The OpenShift client kit targets Linux amd64. Its five images are backend, frontend, gateway, PostgreSQL and the optional test agent. Certificate initialization and Azure gateway are additional release images.

## Vulnerability scans and inventories

Trivy 0.76.1 scans OS and application packages at all severities (UNKNOWN, LOW, MEDIUM, HIGH, CRITICAL), including unfixed advisories. Image scans use comprehensive detection. A scan with missing inventory, known vulnerabilities or suppressed findings fails the release. Each image has its own CycloneDX SBOM. The locked Rust and npm dependencies have an additional SBOM including development dependencies.
Source vulnerability database updated: 2026-11-16T07:10:39.763774809Z. Per-image scanner metadata records the database used for that scan.

| Image | Qualified image and digest | Findings | Scan timestamp |
|---|---|---:|---|
| backend | `appcontrol-backend@sha256:e0348c0b47fca6ee60fc1dea6bbc41eaabc7dc88c6ecc1be499914d60267133b` | 0 | 2026-11-16T11:43:01.252044693Z |
| frontend | `appcontrol-frontend@sha256:dd120dff4b4c6def1fba5109bb2d8a1462de8f248285e98e2d2696dbe318d3e8` | 0 | 2026-11-16T11:43:04.288680918Z |
| gateway | `appcontrol-gateway@sha256:aa3e5898dc4dbf0c6b9d5fe7d6d1c17b3277be73686e8264c5ea8b3e5deb4f0d` | 0 | 2026-11-16T11:42:59.722272987Z |
| agent | `appcontrol-agent@sha256:248bf836493e414a5f646a1d5eb6d0033c858841db23020ba504b756548aa6f6` | 0 | 2026-11-16T11:43:02.212637886Z |
| postgresql | `appcontrol-postgresql@sha256:ccfdd0dbfda349b0b278b183cedf00465e8d920db19299a15bd0e4c7159af8b6` | 0 | 2026-11-16T11:42:58.489576077Z |
| init-certs | `appcontrol-init-certs@sha256:e85367e306b3d997134f2579b79c7798dfc35fd2c08dd0aa08c9c8f0965a35d0` | 0 | 2026-11-16T11:42:51.859934482Z |
| azure-gateway | `appcontrol-azure-gateway@sha256:f8984b1dcf43c6ff1a6e3ee7bb7058f38052c547df5a1326cc7a6ba54a16e354` | 0 | 2026-11-16T11:43:03.056220367Z |

| Dependency scope | Inputs | Findings | Scan timestamp |
|---|---|---:|---|
| Production dependencies | Cargo.lock + frontend/package-lock.json | 0 | 2026-11-16T11:24:27.869708815Z |
| Production and development dependencies | Cargo.lock + frontend/package-lock.json | 0 | 2026-11-16T11:24:32.62169278Z |

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
