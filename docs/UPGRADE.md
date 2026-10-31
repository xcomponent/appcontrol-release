# Upgrading AppControl

The supported OpenShift evaluation profile runs **one backend replica**, with
`Recreate` deployment strategy. Plan an interruption. This release does not
claim a zero-downtime upgrade or general N/N−1 protocol compatibility.

For a first installation, use the versioned OpenShift kit and
[installation guide](qualification/INSTALLATION-EVALUATION.fr.md).

## Before upgrading

1. Read the target release notes and verify its checksums, image digests and
   qualification reports. Use components from the same release.
2. Finish all application operations and suspend new start/stop/rebuild requests.
   Do not interrupt a destructive reconstruction to upgrade its controller.
3. Back up PostgreSQL and **test restoring the backup** in an isolated database.
   Retain the installation's private state directory (credentials and PKI),
   current image lock, Helm values and Helm revision. Protect these as secrets.
4. Rehearse the upgrade on the restored database. An initial-installation test
   does not prove compatibility with every historical schema and dataset.
5. Schedule the interruption and plan recovery with the database owner.

## Apply the version

Import the new kit's OCI archives into the approved registry using
`scripts/qualification/transfer-images.py`. Retain the previous lock; create a
new lock for the new version. Do not overwrite immutable image tags.

Update the non-secret installer configuration to point to the new lock. Keep
the **same private state directory**, namespace and Helm release name:

```sh
python3 scripts/qualification/install.py --config client.json --preflight-only
python3 scripts/qualification/install.py --config client.json
```

Check certificate and gateway-token expiry before using this procedure. The
installer reuses existing credentials; reuse does not extend their validity.
For deployments integrated with a customer PKI, database or SSO, use the reviewed
Helm values and the customer's maintenance procedure instead of regenerating
evaluation secrets.

The backend applies pending numbered migrations at startup and records them in
`_migrations`. PostgreSQL migrations are supplied with the binary; SQLite also
embeds migrations. Ship the matching migration directory with every upgrade.
Each migration is transactional; a failure after earlier migrations succeeded
can leave the database at an intermediate version. Never edit or remove an
already applied migration.

`appcontrol-backend --migrate-only` applies migrations and exits.
`--dry-run` lists pending migrations without executing their SQL, but can create
the migration tracking table. Test both against a restored copy first; they are
not a backup or a database rollback mechanism.

## Verify after the interruption

Check readiness, HTTPS login, gateway and agent reconnection, existing maps and
permissions. Test a non-critical application's approved commands. Investigate
any interrupted operation explicitly; connectivity recovery alone does not
establish whether a command executed before a crash.

The supplied `e2e.py --openshift` recipe restarts services and creates synthetic
commands. Run it only on a dedicated qualification installation, never on a
controller operating customer applications.

Upgrade external agents with the matching platform binary and verify its
SHA-256 before replacement. Keep the previous binary and configuration for
recovery. Stop the service, replace the executable, restart, then verify the
reported version, TLS connection and permitted commands. Qualify the actual
host OS and procedure dependencies before a fleet rollout.

## Rollback

`helm rollback` restores Kubernetes manifests and image references. **It does
not undo database migrations, commands already executed, or certificate changes.**
Do not start an older backend against a changed schema unless that combination
has been tested. If incompatible, stop new operations, restore the verified
pre-upgrade database backup and matching manifests, images and private state.
Reconcile any application action that occurred after the backup before resuming.

There is no general supported-version matrix inferred from version numbers.
The release evidence describes exactly the paths exercised. Upgrade an existing
customer installation only after testing its source version and restored data.

## References

- [Backup and restore](BACKUP_RESTORE.md)
- [Network, images and agents](qualification/RESEAU-IMAGES-AGENTS.fr.md)
- [Release notes](../CHANGELOG.md)
