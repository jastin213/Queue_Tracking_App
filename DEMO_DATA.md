# Final Defense Demo Data

The project includes a deterministic Firebase demo-data seeder. It creates
fictional queue and appointment history for Daily Report, Analytics, plate/name
search, the appointment calendar, and the pending appointment document viewer.

Every generated document contains:

- `isDemo: true`
- `seedBatchId: final-defense-2026`
- `demoLabel: FINAL DEFENSE SAMPLE DATA` where applicable

The seeder never creates Firebase Authentication accounts and never uses real
IDs, receipts, registrations, email addresses, or plate numbers. The three
files attached to the pending sample appointment are generated PDFs clearly
labelled `DEMO DOCUMENT - NOT A REAL CUSTOMER FILE`.

## Developer-only command-line method

Demo-data controls are intentionally not shown anywhere in the application.
Only a developer with authorized Firebase administrator credentials can run the
seeder from the project workspace.

For automated development environments, use a Firebase service-account JSON through the standard
`GOOGLE_APPLICATION_CREDENTIALS` environment variable. Never copy its contents
into this repository. Common service-account filenames are ignored by Git.

PowerShell example:

```powershell
$env:GOOGLE_APPLICATION_CREDENTIALS = "C:\secure\service-account.json"
```

## Preview

Preview counts without writing data:

```powershell
npm --prefix functions run demo:preview -- --date=2026-08-30
```

If `--date` is omitted, the current date in Asia/Manila is used.

## Seed

Write and verify the demo records:

```powershell
npm --prefix functions run demo:seed -- --date=2026-08-30 --apply
```

Running the same batch and date again is idempotent. The script refuses to
overwrite a real record or a record from a different demo batch. To use another
anchor date, clean the existing batch first.

## Cleanup

Remove only paths listed in the batch's Firestore manifest:

```powershell
npm --prefix functions run demo:cleanup -- --apply
```

Before deletion, every existing target is checked again for matching `isDemo`
and `seedBatchId` values. Cleanup stops without deleting anything if a target
cannot be verified as demo data.
