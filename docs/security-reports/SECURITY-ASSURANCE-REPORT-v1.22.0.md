# AppControl v1.22.0 — release qualification report

Generated: 2026-11-06T20:46:58.021020+00:00
Source commit: `608b801c07ac64308e6a7408de9d82587aed2062`
Release workflow: https://github.com/fredericcarre/appcontrol/actions/runs/42285470589

## Scope and result

PASS: the checks listed below completed for this commit and these immutable image digests. This is dated technical qualification, not certification for every production environment or a guarantee of absence of undiscovered vulnerabilities.

The OpenShift client kit targets Linux amd64. Its five images are backend, frontend, gateway, PostgreSQL and the optional test agent. Certificate initialization and Azure gateway are additional release images.

## Vulnerability scans and inventories

Trivy 0.76.1 scans OS and application packages at all severities (UNKNOWN, LOW, MEDIUM, HIGH, CRITICAL), including unfixed advisories. No ignore file, vulnerability suppression or severity exclusion is used. Each image has its own CycloneDX SBOM; locked Rust and npm dependencies have an additional SBOM including development dependencies.
Source vulnerability database updated: 2026-11-06T18:59:52.855177206Z. Per-image scanner metadata records the database used for that scan.

| Image | Delivered immutable reference | Findings | Scan timestamp |
|---|---|---:|---|
| backend | `ghcr.io/fredericcarre/appcontrol-backend@sha256:2ba5130daf70e320ac48c91370fdfea2ceb3d22fb3c9bdf4d9ab59752e0efbd4` | 0 | 2026-11-06T20:42:05.536232717Z |
| frontend | `ghcr.io/fredericcarre/appcontrol-frontend@sha256:af6d68d435c332317e9b3997e97c5da87504be12577cacd2139c280bf524e849` | 0 | 2026-11-06T20:42:01.365736345Z |
| gateway | `ghcr.io/fredericcarre/appcontrol-gateway@sha256:59237d1fffa7487fd0bbdc05fb03ca1b55e6eea073180bb8e3479f5048507613` | 0 | 2026-11-06T20:42:03.258287174Z |
| agent | `ghcr.io/fredericcarre/appcontrol-agent@sha256:bb18205203fe7e1947abf61cd6a316e9146fc5ba2319ed06b84acd09accc77d8` | 0 | 2026-11-06T20:41:59.121602328Z |
| postgresql | `ghcr.io/fredericcarre/appcontrol-postgresql@sha256:223daad73e92ab3bd9a34af782640f6ebfaae8f25c4f21621400c0a0d13afafe` | 0 | 2026-11-06T20:42:05.817270692Z |
| init-certs | `ghcr.io/fredericcarre/appcontrol-init-certs@sha256:cf714b91dafb4111321c834a5459f4de646ef100e9b38b49146cbd712c229b38` | 0 | 2026-11-06T20:42:09.319102208Z |
| azure-gateway | `ghcr.io/fredericcarre/appcontrol-azure-gateway@sha256:ced18c90b08591b06a080de0c08a848c19781a3c3ef2f77e794960f2ec9f6580` | 0 | 2026-11-06T20:42:06.722247776Z |

| Dependency scope | Inputs | Findings | Scan timestamp |
|---|---|---:|---|
| Production dependencies | Cargo.lock + frontend/package-lock.json | 0 | 2026-11-06T20:07:08.033068306Z |
| Production and development dependencies | Cargo.lock + frontend/package-lock.json | 0 | 2026-11-06T20:07:22.444921899Z |

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
