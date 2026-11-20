# Identity and access deployment

This guide describes the implemented login and permission controls. Qualify the
customer identity provider and emergency procedure before changing a live login
policy. Examples use fictitious identities and do not contact a client system.

## Login policy

`APP_ENV=production` enables production configuration checks. It does not disable
password login. Select the policy explicitly:

| Setting | Result |
| --- | --- |
| `AUTH_MODE=hybrid` | Default; local passwords and configured SSO are available |
| `AUTH_MODE=sso_only` | Local passwords are refused except for explicitly permitted emergency administrators |
| `AUTH_MODE=local_only` | Password login remains available; SSO login/callback routes are disabled |
| `AUTH_LOCAL_EMERGENCY_USER_IDS` | Comma-separated UUIDs of active local organization admins permitted to log in with a password under `sso_only` |

Keep emergency passwords in the approved vault. Listing a UUID does not activate
a disabled user, promote a user, or create a password. Configure at least one
usable, reviewed login path before selecting `sso_only`.

MFA must be enforced and tested at the IdP. The presence of an OIDC/SAML
connection does not attest MFA. Signed authentication-context information is
provider evidence, not an AppControl compliance certification.

## Provider trust and account binding

| OIDC variable | Meaning |
| --- | --- |
| `OIDC_DISCOVERY_URL` | HTTPS discovery URL; absent or blank disables OIDC |
| `OIDC_ISSUER` | Exact expected issuer. Without it, only a standard discovery URL ending in `/.well-known/openid-configuration` determines the issuer |
| `OIDC_CLIENT_ID`, `OIDC_CLIENT_SECRET` | Required, nonblank client credentials when enabled |
| `OIDC_REDIRECT_URI` | Required absolute HTTPS callback URL, exactly registered at the IdP |
| `OIDC_SCOPES` | Requested scopes; default `openid,profile,email` |
| `OIDC_ORGANIZATION_ID` | Target organization UUID. If absent, exactly one existing organization is required |
| `OIDC_LEGACY_LINK_ISSUER` | Temporary, explicit opt-in to link a unique historical `oidc_sub` for this exact issuer; never an email match |

Discovery metadata must match the trusted issuer. Discovery, authorization,
token, JWKS and userinfo URLs require HTTPS; backend HTTP calls verify TLS and
refuse redirects. OIDC uses S256 PKCE, a browser-bound single-use login
transaction, nonce, and a signed ID token. Supported asymmetric algorithms are
RS256/384/512, PS256/384/512, ES256/384 and EdDSA, constrained by provider metadata
and JWKs; HMAC and unsigned tokens are rejected. Subject, issuer, audience,
expiry, issue time and nonce are checked; userinfo cannot substitute a different
subject. Provider metadata must support the client authentication method used.

| SAML variable | Meaning |
| --- | --- |
| `SAML_IDP_SSO_URL` | IdP login URL; absent or blank disables SAML |
| `SAML_IDP_ENTITY_ID` | Required exact issuer/entity ID |
| `SAML_IDP_CERT` | Required pinned signing certificate: PEM, base64 PEM or base64 DER content |
| `SAML_SP_ENTITY_ID`, `SAML_SP_ACS_URL` | Required audience/entity ID and exact callback destination |
| `SAML_ORGANIZATION_ID` | Target organization UUID. If absent, exactly one existing organization is required |
| `SAML_LEGACY_LINK_ISSUER` | Temporary, explicit opt-in for a unique historical `saml_name_id` in this exact issuer and organization |
| `SAML_WANT_ASSERTIONS_SIGNED` | Default `true`: directly signed Assertion required. `false` also permits a verified signed Response covering its Assertion; it never permits unsigned claims |
| `SAML_GROUP_ATTRIBUTE`, `SAML_EMAIL_ATTRIBUTE`, `SAML_NAME_ATTRIBUTE` | Attribute names; defaults `memberOf`, `email`, `displayName` |
| `SAML_ADMIN_GROUP` | Optional explicit trusted group controlling admin/viewer for SAML-managed accounts; does not override locally managed roles |

SAML verifies XML signatures against the pinned certificate, request correlation,
issuer, audience, destination and bounded validity. It supports RSA SHA-256/384/512
with SHA-2 digests and keys of at least 2048 bits. Replay identifiers and login
transaction consumption persist with the account/audit writes. IdP and backend
clocks must be synchronized. The IdP's cross-site POST needs a Secure,
HttpOnly, `SameSite=None` login-flow cookie, including local qualification.

Both providers identify users by **issuer and stable subject**, inside the target
organization. New OIDC users receive `viewer`. New SAML users receive `viewer`
unless an explicitly configured trusted `SAML_ADMIN_GROUP` grants a SAML-managed
admin role. An existing email address cannot
transfer an account or confer its privileges. A collision is refused for review.
Inactive accounts are refused. Local administrator authority remains local.
For `role_source=saml`, an explicitly configured `SAML_ADMIN_GROUP` controls the
admin/viewer role from signed group claims; losing the group demotes the account
and invalidates earlier sessions. SAML synchronizes only
configured team mappings in the organization and only removes memberships it
previously created for that issuer. Local memberships and team leads remain.

## Explicit binding for an existing account

An authenticated organization administrator can bind an existing active account
through `POST /api/v1/users/{id}/external-identities` with
`{"provider":"oidc","issuer":"https://identity.example.test/issuer","subject":"stable-provider-subject"}`
(or provider `saml`). The issuer must exactly match this installation's provider
trust configuration and its target organization. Obtain the stable subject from
the provider's reviewed identity record, never from an email inference. A subject
already bound to another account is a conflict. Scoped API keys cannot use this
administrative endpoint.

Some historical SAML accounts have a `saml_name_id` while still carrying
`auth_provider=local`. The legacy issuer opt-in does not migrate these accounts.
An administrator must review the exact issuer/NameID and bind the existing
account explicitly through this API. Review its current organization role and
`role_source` at the same time. Manual binding authorizes that external identity
to authenticate; it does not delegate locally managed role authority to SAML or
make an asserted group authoritative over an existing local administrator.

`DELETE /api/v1/users/{id}/external-identities/{provider}` removes that provider's
bindings and clears the old legacy subject column to prevent automatic relinking.
SAML-derived role authority is removed; explicitly local roles and memberships
remain. Both operations audit and invalidate older account sessions in the same
transaction. Binding alone does not delegate role management to the provider.

## Accounts and revocation

Creating users, changing roles/passwords, deactivating accounts and revoking
another user's sessions require an organization administrator. A user may revoke
their own sessions through `POST /api/v1/users/{id}/revoke-sessions`.

New/reset passwords require at least 12 characters and no more than 72 UTF-8
bytes, preventing bcrypt truncation. Existing password hashes are preserved.
Passwords and hashes are omitted from API responses and audit details.

Account authentication versions invalidate earlier JWTs after an account,
password or access change, or explicit session revocation. Each authenticated
request checks current account state. X4B handoffs and external sessions use the
same account version, so an old external session cannot restore revoked access.
Individual API keys remain governed by their owner state and their own scope,
expiry and revocation controls; they are not converted into SSO identities.

Application grants remain ordered `view < operate < edit < manage < owner`.
A manager cannot lower or revoke an existing Owner grant. Workspace mutations
require an organization administrator, same-organization site/user/team
references, exactly one membership target and role `admin` or `member`.

Share-link redemption rechecks organization, active account, execution-site
workspace access, expiry, allowed permission and capacity while holding the
database lock. The audit, grant and use counter commit together. Concurrent
requests cannot exceed `max_uses`. Existing higher permissions and their expiry
are preserved; link expiry limits redemption and does not change an existing
grant's lifetime.

## Emergency incident recording

The separate `/api/v1/break-glass/activate` endpoint verifies an emergency account
and returns **session metadata**, not a login JWT. Its current implementation
does not bypass application permissions, automatically rotate the password or
promise email notification delivery. Use the reviewed local administrator
exception for actual login during an IdP outage.

Emergency passwords use bcrypt cost 12, with the same minimum 12 characters and
maximum 72 UTF-8 bytes. The old XOR/base64 format never authenticates. Activation
requires a reason and records the audit and session in one transaction. A
username present in multiple organizations requires `organization_id` in the
activation body. The recording duration defaults to 60 minutes and is bounded
to 5–120 minutes. An administrator ends a session by appending to
`break_glass_session_ends`; its original activation is retained.

## Upgrade and qualification

1. Back up the database, PKI, provider configuration, private installer state and
   exact Secret references. Rehearse against an isolated restored database.
2. Legacy `AUTH_MODE=local|oidc|saml` strings are normalized to `hybrid` with a
   warning, preserving the historical availability of local and configured SSO.
   Select `sso_only` explicitly to require SSO and verify emergency identities
   before imposing it. Other unsupported policy strings are refused.
3. Configure exact issuer/entity IDs, organization UUIDs and absolute callback
   URLs. For historical identity migration, compare the stored stable subject
   and provider before temporarily setting the exact legacy-link issuer. Email
   is never a migration key. Remove this opt-in after migration review.
4. Apply V084 with the matching binary/migrations. It adds account versions,
   scoped provider identities, single-use browser transactions, replay records
   and append-only emergency endings. Legacy weak emergency accounts are
   deactivated. An authorized admin can POST the same inactive legacy username
   with a new password to replace its hash while preserving its account ID.
5. Check both configured SSO and ordinary local login behavior with fictitious
   users. Reject wrong issuer/audience/destination, replayed or expired callbacks,
   unsigned claims, mismatched browser flow, cross-organization recipients and
   ambiguous identity matches. Check deactivation, role/password changes and
   global revocation against AppControl and an existing X4B session.
6. Exercise workspace references, Owner-grant protection and two simultaneous
   redemptions of a link with `max_uses=1`. Inject an audit-storage failure in the
   isolated fixture and verify no access grant or counter change is committed.

The Windows manifest installer checks both the new candidate environment and
retained settings before any resource or Secret write, and repeats the check
immediately before applying the final manifest. An active SAML provider requires
its issuer/entity ID, SSO URL, pinned certificate, SP entity ID and ACS URL. OIDC
requires its discovery URL, client ID, client-secret reference and absolute HTTPS
callback. Missing or invalid inputs stop the update without changing login mode.
Explicit non-optional Secret references are checked for their name/key wiring;
their contents are never read or printed. The backend validates their actual
values at startup. Implicit `envFrom` authentication configuration must be made
explicit for this preflight. A Helm installation with custom identity settings
must use its reviewed Helm values instead of the evaluation installer's generated
values, preventing an accidental replacement by local/default settings.

The Windows update path retains `AUTH_*`, `OIDC_*` and `SAML_*` backend environment
entries and their explicit Secret references. Literal OIDC client secrets must
be moved to a Secret before an update. Legacy `local`, `oidc` and `saml` values become `hybrid` with a warning;
other unsupported login-mode values are refused before replacing settings. Helm exposes non-secret provider settings under
`backend.env` and the OIDC client secret through `backend.sso.existingSecret`.
The JSON organization setup does not store passwords or configure IdP trust.
