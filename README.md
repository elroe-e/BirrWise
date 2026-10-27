# BirrWise

BirrWise is an offline-first Flutter personal-finance app for Ethiopian Birr.
The app keeps accounts, transactions, savings goals, recurring bills, settings,
and SMS reviews in private local app storage. It does not request internet
access or connect to a service. Optional Android bank-SMS tracking is off until
you enable it and grant Android's SMS permissions.

## Run

Install Flutter (Dart 3.5 or newer), then from this directory:

```sh
flutter pub get
flutter test
flutter build apk --debug
```

The debug APK is written to
`build/app/outputs/flutter-apk/app-debug.apk`. Use `flutter run` to launch the
app on a connected Android device or emulator.

## Bank SMS automation

On first open, BirrWise explains SMS scanning and asks whether to request
Android's inbox and incoming-SMS permissions. You can decline and enable it
later in **Settings → Auto-track bank SMS**. When enabled, it scans supported
bank senders (Telebirr, CBE, Awash, BOA and Dashen). BirrWise only reads
messages from exact, allow-listed sender IDs for transaction parsing. It scans
the existing inbox once, and **Scan bank alerts now** can explicitly rescan it.
New alerts are checked when BirrWise opens or resumes.
New-alert detection is handled locally by Android while BirrWise is closed;
messages are queued on the device and imported on the next app launch or resume.
No SMS content leaves the phone.
The debug APK includes Android's `INTERNET` permission for Flutter development
and debugging tools; the app itself makes no network requests.

An alert is added without confirmation when its amount and direction are clear,
exactly one non-archived account matches its institution, and it arrived after
both that account was added and tracking was turned on; a reference is not
required. Older alerts (the one-time scan covers the last 30 days) stay in the
review inbox, because the opening balance or your manual entries probably
already include them. Confirming an alert that reports a balance offers to
match the account to it. Unknown or ambiguous transactions stay in the SMS
review inbox; unrelated or unrecognized messages are ignored. Deduplication uses the transaction
reference when present and a local content/time fingerprint otherwise. Turning
the feature off stops the receiver and clears its temporary incoming-message
queue. Manual paste-and-review remains available and never automatically adds
transactions.
The original SMS is cleared from storage after a clear alert is automatically
added; original text remains stored for messages awaiting review. Older
messages that were already entered manually before enabling SMS scanning may
not be recognizable as duplicates, so check the ledger for those entries.

The Android receiver and SMS permissions are intended for this opt-in,
sideloaded test build. Google Play restricts SMS permissions; review its current
SMS-permission policy and eligibility before distributing this app through
Google Play.

## Data and privacy

Balances are stored in integer santim (100 santim = 1 ETB) and derived from
opening balances plus ledger entries. SharedPreferences stores app data locally;
this is app-private storage, not encrypted storage. Pending review alerts
include their original SMS text so you can check their classification. CSV
export copies the selected ledger data to the clipboard, which other apps may be able to access.
There is no cloud backup or network sync implemented. SharedPreferences data is
not encrypted. Android backup and device-to-device transfer are disabled
(`allowBackup="false"` plus data-extraction rules that exclude everything). The Ethiopian calendar changes
date labels and monthly summaries; the system date-picker itself remains
Gregorian.
