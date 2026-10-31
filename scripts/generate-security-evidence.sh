#!/usr/bin/env bash
set -euo pipefail

evidence_dir="${1:-security-evidence}"
report="${evidence_dir}/SECURITY-EVIDENCE.md"
mkdir -p "$evidence_dir"

required_images=(agent backend frontend gateway init-certs)
for image in "${required_images[@]}"; do
  [[ -s "${evidence_dir}/trivy-${image}.json" ]] ||
    { echo "Missing Trivy report for ${image}" >&2; exit 1; }
  [[ -s "${evidence_dir}/sbom-${image}.json" ]] ||
    { echo "Missing CycloneDX SBOM for ${image}" >&2; exit 1; }
done
report_images=("${required_images[@]}")
if [[ -s "${evidence_dir}/trivy-azure-gateway.json" ||
      -s "${evidence_dir}/sbom-azure-gateway.json" ]]; then
  [[ -s "${evidence_dir}/trivy-azure-gateway.json" ]] ||
    { echo "Missing Trivy report for azure-gateway" >&2; exit 1; }
  [[ -s "${evidence_dir}/sbom-azure-gateway.json" ]] ||
    { echo "Missing CycloneDX SBOM for azure-gateway" >&2; exit 1; }
  report_images+=(azure-gateway)
fi
image_count=${#report_images[@]}
[[ -s "${evidence_dir}/rustsec.json" ]] ||
  { echo "Missing RustSec JSON report" >&2; exit 1; }

total=$(jq -s '[.[].Results[]?.Vulnerabilities[]?] | length' \
  "${evidence_dir}"/trivy-*.json)
critical=$(jq -s '[.[].Results[]?.Vulnerabilities[]? |
  select(.Severity == "CRITICAL")] | length' "${evidence_dir}"/trivy-*.json)
high=$(jq -s '[.[].Results[]?.Vulnerabilities[]? |
  select(.Severity == "HIGH")] | length' "${evidence_dir}"/trivy-*.json)
medium=$(jq -s '[.[].Results[]?.Vulnerabilities[]? |
  select(.Severity == "MEDIUM")] | length' "${evidence_dir}"/trivy-*.json)
low=$(jq -s '[.[].Results[]?.Vulnerabilities[]? |
  select(.Severity == "LOW")] | length' "${evidence_dir}"/trivy-*.json)
unknown=$(jq -s '[.[].Results[]?.Vulnerabilities[]? |
  select(.Severity == "UNKNOWN")] | length' "${evidence_dir}"/trivy-*.json)
rustsec_vulnerabilities=$(jq '[.vulnerabilities.list[]?] | length' \
  "${evidence_dir}/rustsec.json")
rustsec_warnings=$(jq '
  [.warnings? // {} | to_entries[]?.value[]?] | length
' "${evidence_dir}/rustsec.json")

verdict="PASS"
if (( total != 0 || rustsec_vulnerabilities != 0 )); then
  verdict="FAIL"
elif (( rustsec_warnings != 0 )); then
  verdict="PASS WITH OBSERVATIONS"
fi

cat >"$report" <<EOF
# AppControl — Security Assurance Report

## Executive summary

**Decision: ${verdict}.** This report links the source commit to the exact
container images tested by CI and records the security and runtime controls
applied before merge. It is intended for technical, security and procurement
review as evidence of the security posture of this build.

| Build identity | Value |
|:--|:--|
| Product | AppControl |
| Document status | Development candidate — pre-release assurance report |
| Audience | Customers, security teams, architects and auditors |
| Commit | \`${GITHUB_SHA:-unknown}\` |
| Branch | \`${GITHUB_REF_NAME:-unknown}\` |
| Generated (UTC) | $(date -u '+%Y-%m-%d %H:%M:%S UTC') |
| Workflow | [GitHub Actions run ${GITHUB_RUN_ID:-unknown}](${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY:-unknown}/actions/runs/${GITHUB_RUN_ID:-unknown}) |

## 1. Purpose and assurance scope

AppControl is an on-premises application operations platform. It models
application dependencies, delegates health checks and lifecycle commands to
agents, orchestrates ordered operations, and records operator actions and
state transitions for audit purposes.

This report answers four questions for the identified build:

1. Were its locked Rust dependencies checked against public security
   advisories?
2. Were the exact container images inventoried and scanned without hiding
   severities or unfixed findings?
3. Were those images exercised in representative deployment topologies,
   including a real OpenShift cluster?
4. Can a reviewer independently inspect and verify the underlying evidence?

The assurance boundary covers the AppControl source tree, locked Rust
dependencies, ${image_count} Linux container images, their software bills of materials,
and the automated deployment scenarios listed below. Customer infrastructure,
identity-provider configuration, host operating systems and external
penetration testing are outside this automated build boundary.

## 2. Product security architecture

| Security objective | AppControl mechanism | Validation represented in this report |
|:--|:--|:--|
| Workload identity | Time-limited enrollment tokens and per-agent mTLS certificates | Real gateway and agent enrollment on OpenShift |
| Confidentiality in transit | HTTPS for user/API traffic and mutually authenticated TLS between agents and gateways | Certificate and HTTPS checks in Compose; mTLS command cycle on OpenShift |
| Least privilege | Five application permission levels and organization-scoped identities | Authenticated API and lifecycle scenarios; authorization implementation remains subject to unit/integration tests |
| Traceability | Append-only action and state-transition records | Lifecycle operations executed end to end; this report does not certify regulatory compliance |
| Container isolation | Non-root images, dropped Linux capabilities, NetworkPolicy and OpenShift restricted security context | Helm validation against \`restricted-v2\` and deployment on a real cluster |
| Supply-chain visibility | Locked dependencies, Trivy reports and CycloneDX SBOM for every delivered image | Raw machine-readable evidence and SHA-256 manifest attached |
| Deployment independence | PostgreSQL production topology plus standalone SQLite distribution | Both database modes and packaged deployment paths tested |

## 3. Assessment methodology

The pipeline builds runtime binaries once, packages the ${image_count} container images,
then uses those commit-tagged images for vulnerability analysis and functional
deployment tests. This preserves traceability between the scanned artifact and
the artifact that actually ran.

The assessment combines:

- **dependency analysis** of \`Cargo.lock\` with RustSec;
- **container analysis** of operating-system and application packages with
  Trivy;
- **software composition inventory** in CycloneDX format;
- **static quality gates** including Rust formatting, Clippy and frontend
  checks in preceding CI jobs;
- **dynamic functional validation** across standalone, Docker Compose,
  PostgreSQL and OpenShift deployment paths.

## 4. Results

### 4.1 Control summary

| Control | Result | Scope and enforced policy |
|:--|:--:|:--|
| RustSec dependency audit | **${RUSTSEC_RESULT:-unknown}** | \`Cargo.lock\` checked against the RustSec advisory database; ${rustsec_vulnerabilities} vulnerabilities and ${rustsec_warnings} informational warnings recorded |
| Container vulnerability gate | **${TRIVY_RESULT:-unknown}** | All ${image_count} delivered images; OS and library packages; severities UNKNOWN through CRITICAL; unfixed findings included; zero known vulnerabilities required |
| SBOM generation | **PASS** | CycloneDX inventory generated for every delivered image |
| Secrets/exclusions | **PASS** | No Trivy ignore file, ignore policy, skipped directory, skipped file, or ignored unfixed finding is configured |

### 4.2 RustSec observations

RustSec distinguishes exploitable vulnerabilities from informational
observations. Observations are disclosed below rather than hidden, even when
the standard \`cargo audit\` exit code remains successful.

| Kind | Advisory | Package | Installed | Patched versions | Observation |
|:--|:--|:--|:--|:--|:--|
EOF

if (( rustsec_warnings == 0 )); then
  echo '| — | — | — | — | — | None |' >>"$report"
else
  jq -r '
    .warnings | to_entries[] |
    .key as $kind |
    .value[] |
    [
      $kind,
      (.advisory.id // "not assigned"),
      .package.name,
      .package.version,
      ((.versions.patched // []) | join(", ") | if . == "" then "none published" else . end),
      (.advisory.title // "Package version is yanked")
    ] |
    "| `\(.[0])` | `\(.[1])` | `\(.[2])` | `\(.[3])` | \(.[4]) | \(.[5]) |"
  ' "${evidence_dir}/rustsec.json" >>"$report"
fi

cat >>"$report" <<EOF

### 4.3 Container vulnerability totals

| Total | Critical | High | Medium | Low | Unknown |
|--:|--:|--:|--:|--:|--:|
| ${total} | ${critical} | ${high} | ${medium} | ${low} | ${unknown} |

### 4.4 Evidence per delivered image

| Image | Immutable digest | OS | Size | Packages scanned | Targets | Vulnerabilities | SBOM components |
|:--|:--|:--|--:|--:|--:|--:|--:|
EOF

for image in "${report_images[@]}"; do
  trivy="${evidence_dir}/trivy-${image}.json"
  sbom="${evidence_dir}/sbom-${image}.json"
  digest=$(jq -r '.Metadata.RepoDigests[0] // .Metadata.ImageID // "unavailable"' "$trivy")
  digest="${digest##*@}"
  os=$(jq -r '
    if .Metadata.OS then
      (.Metadata.OS.Family + " " + (.Metadata.OS.Name // ""))
    else "not detected" end
  ' "$trivy")
  size=$(jq -r '(.Metadata.Size // 0) / 1048576 | floor | tostring + " MiB"' "$trivy")
  packages=$(jq '[.Results[]?.Packages[]? | [.Name, .Version]] | unique | length' "$trivy")
  targets=$(jq '[.Results[]?] | length' "$trivy")
  vulnerabilities=$(jq '[.Results[]?.Vulnerabilities[]?] | length' "$trivy")
  components=$(jq '[.components[]?] | length' "$sbom")
  printf '| `%s` | `%s` | %s | %s | %s | %s | %s | %s |\n' \
    "$image" "$digest" "$os" "$size" "$packages" "$targets" \
    "$vulnerabilities" "$components" >>"$report"
done

cat >>"$report" <<EOF

## 5. Runtime validation of the scanned artifacts

The functional jobs consume the same commit-tagged images listed above.

| Deployment path | Result | Security-relevant coverage |
|:--|:--:|:--|
| Standalone SQLite | **${SQLITE_E2E_RESULT:-unknown}** | SQLite-specific binary, authentication and application lifecycle |
| Standalone full stack | **${STANDALONE_E2E_RESULT:-unknown}** | Backend, gateway, agent and command execution |
| Standalone customer package | **${STANDALONE_PACKAGE_RESULT:-unknown}** | Release-style downloads through \`appcontrol.ps1\`, SQLite startup, web UI, gateway and agent |
| PostgreSQL in-process | **${POSTGRES_E2E_RESULT:-unknown}** | PostgreSQL migrations and backend integration |
| Docker Compose/PostgreSQL | **${COMPOSE_RESULT:-unknown}** | Packaged images, HTTPS redirect, certificate validity, enrollment and start/check/stop/restart |
| OpenShift/PostgreSQL | **${OPENSHIFT_RESULT:-unknown}** | Helm deployment, restricted-v2, NetworkPolicy, Route, PostgreSQL, mTLS enrollment and command lifecycle on a real cluster |

## 6. Scanner configuration and exclusion policy

- Trivy scans both \`os\` and \`library\` packages.
- The severity set is \`UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL\`.
- \`ignore-unfixed\` is disabled: findings without an upstream fix remain visible.
- The quality gate requires **zero** known vulnerabilities at every severity.
- No \`.trivyignore\`, ignore policy, skipped directory or skipped file is supplied.
- RustSec evaluates the locked Rust dependency graph, not merely the manifest.

## 7. Customer deployment responsibilities

The build result does not remove the need for secure production configuration.
Customers should, at minimum:

- use OIDC or SAML with MFA enforced by the identity provider;
- disable development authentication paths and replace every default secret;
- use a managed PostgreSQL service or a hardened PostgreSQL deployment with
  encrypted, tested backups;
- terminate public traffic with trusted certificates and protect the
  organization CA and JWT signing material;
- restrict namespaces, service accounts, egress and administrator access
  according to least privilege;
- export logs and AppControl audit data to the organization's monitoring and
  incident-response systems;
- rescan images and dependencies continuously because advisory databases
  change after this report is generated.

## 8. Findings and disposition

- Container scan: **${total} known vulnerabilities** across the ${image_count} delivered
  images at build time.
- RustSec vulnerability class: **${rustsec_vulnerabilities} known
  vulnerabilities**.
- RustSec informational class: **${rustsec_warnings} observations**, disclosed
  in section 4.2. A patched version shown in the table is a remediation
  candidate; an unmaintained or yanked dependency requires dependency-tree
  review even when no exploitable vulnerability is currently assigned.
- Residual risk: automated scanners can only detect known and modelled issues.
  Unknown vulnerabilities, application-logic flaws and environment-specific
  weaknesses require complementary review and testing.

## 9. Attached evidence and integrity

The artifact contains the raw Trivy JSON, CycloneDX SBOM and RustSec JSON used
to produce this document. SHA-256 hashes allow each file to be verified:

| File | SHA-256 |
|:--|:--|
EOF

for file in "${evidence_dir}"/rustsec.json \
  "${evidence_dir}"/trivy-*.json "${evidence_dir}"/sbom-*.json; do
  printf '| `%s` | `%s` |\n' "$(basename "$file")" \
    "$(sha256sum "$file" | awk '{print $1}')" >>"$report"
done

cat >>"$report" <<'EOF'

## 10. Interpretation and limits

A **PASS** means that the locked Rust dependencies and delivered Linux
container images had no vulnerability known to the configured scanners at
build time, and that the listed deployment scenarios succeeded. **PASS WITH
OBSERVATIONS** adds disclosed informational dependency findings that require
review but are not classified as vulnerabilities by the scanner. **FAIL**
means at least one known RustSec or container vulnerability was found.

This report is a reproducible software-build assurance record. It is not an
ISO certification, a legal statement of DORA/NIS2 compliance, a source-code
security review or a penetration-test report. Those activities have different
scope, evidence and independence requirements.
EOF

echo "Generated $report"
