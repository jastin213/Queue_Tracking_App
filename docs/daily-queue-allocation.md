# Daily queue allocation on Firebase Spark

NPJN uses one daily limit shared by Gas and Diesel. At the initial limit of 80,
40 places belong to appointments and 40 belong to walk-in customers. Unused
places remain reserved for their group. Pending and approved appointments reserve
a place; rejection, expiry, cancellation, and reset release an unfinished place.
Passed and failed services continue to consume the original group's daily place.

The implementation uses Firestore transactions and Firebase Security Rules. It
does not require Cloud Functions, a billing account, or a change from Spark.
Firebase Authentication still verifies users, and the existing appointment review
and approval settings continue to control approval decisions.

## Atomic reservations

Each reservation changes the source record and its `capacity_days/{M-D-YYYY}`
metadata together. Rules validate the associated claim, the source allocation,
and the combined limit. Client-side availability helps users choose; the atomic
rules check decides whether a concurrent submission is accepted. Retries reuse
the same reservation identity.

The schema-v2 ledger contains appointment claims keyed by appointment document
ID, walk-in claims keyed by request identity, completed claims, and immutable
legacy queue bindings. Bindings identify older queue records without changing
those records. Different appointment IDs remain separate reservations even if
older records share a queue code. Historical over-capacity records are preserved;
new reservations remain blocked while the applicable limit is full.

## Initial deployment and migration

1. Review and test the Spark rules and client against local emulators.
2. Deploy the reviewed rules and place the capacity configuration into the
   documented migration state: `schemaVersion: 2`, `dailyLimit: 80`, and
   `migrationComplete: false`. This briefly freezes quota-changing writes from
   older clients. Keep that freeze active until verification succeeds.
3. Run the read-only inventory from the project root:

   ```powershell
   node functions/scripts/spark_capacity_migration.js --project=npjn-queue-system-jkr
   ```

4. Review the date-level counts, then apply the metadata-only migration:

   ```powershell
   node functions/scripts/spark_capacity_migration.js --project=npjn-queue-system-jkr --apply
   ```

   The script uses the already authorized Firebase CLI account in memory. It
   creates missing day ledgers with an existence precondition, skips initialized
   v2 ledgers, rechecks source hashes and complete ledger contents, and enables
   `migrationComplete` only after every recorded day verifies. It refuses to
   overwrite a production legacy ledger. Failed verification leaves the freeze
   active. Source appointments, queue items, uploads, reports, profiles, and billing
   settings are never rewritten. The local summary under `output/deployment/`
   contains only project/date/count/hash information.

5. Deploy the newly built web client with emulator mode disabled. Refresh older
   browser tabs so reservations use the new atomic flow. Old clients cannot bypass
   the allocation by writing source records alone.
6. Verify the deployed build, signed-in capacity display, and denied unauthorized
   writes. Keep tests that create sample reservations in local emulators.

The migration reads all existing source dates, including historical dates, so a
missing ledger after activation represents a date without pre-migration records.
An initialized ledger is never reset by rerunning the migration. A migration rerun
requires the explicit freeze configuration again and will refuse activation if
existing claims disagree with the current source inventory.

## Emulator verification

Use `--emulator` together with a loopback `FIRESTORE_EMULATOR_HOST` and the same
explicit project argument. In this mode only, an older local ledger may be replaced
to prepare repeatable fixtures. Production mode refuses an emulator environment;
emulator mode refuses a remote host. Build the local app with
`--dart-define=USE_FIREBASE_EMULATORS=true`; production builds must use `false`.

No Cloud Functions deployment is part of this feature.
