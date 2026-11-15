# BirrWise

BirrWise is an offline-first Flutter personal-finance app for Ethiopian Birr.
The app keeps accounts, transactions, savings goals, recurring bills, settings,
and SMS reviews in private local app storage. It connects to nothing unless you
link a shop (see below). Optional Android bank-SMS tracking is off until you
enable it and grant Android's SMS permissions.

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
bank and wallet senders (Telebirr, CBE, CBE Birr, Awash, Awash Birr, BOA,
Dashen, Amole, M-PESA, Coopay/E-Birr, Coop Bank, Berhan, Bunna, Hibret and
Ahadu; untick any of them in Settings). BirrWise only reads
messages from exact, allow-listed sender IDs for transaction parsing. It scans
the existing inbox once, and **Scan bank alerts now** can explicitly rescan it.
New alerts are checked when BirrWise opens or resumes.
New-alert detection is handled locally by Android while BirrWise is closed;
messages are queued on the device and imported on the next app launch or resume.
No SMS content leaves the phone.
BirrWise makes no network requests unless you link a shop (Settings → Shop
payments). Then, when an incoming-money alert arrives, the Android receiver
sends its amounts, bank and time to that shop's Supabase function
`claim_shop_payment`, which marks a staff-entered expected payment as received
when the amount matches and stores nothing otherwise. Spending alerts, message
text and balances other than as candidate amounts are never sent. Failed sends
are retried for up to two days.

Alerts for loyalty points, loan offers and failed transactions are ignored;
reversals and refunds are kept.

## Notifications, codes, reports and receipts

- **Transaction notifications** (Settings → Notifications, off by default):
  the Android receiver posts "Received ETB 500.00 · CBE" for each alert, even
  with BirrWise closed. Unticked banks never notify; on a locked screen only
  "New bank alert" shows when Android hides sensitive content.
- **Verification codes** (off by default): the receiver reads every incoming
  SMS only to find a 4–8 digit code, then shows it with a Copy button. The code
  is never stored, logged or sent, is copied as sensitive, and the
  notification expires after five minutes (Android 8+).
- **Calendar**: Insights shows each day's money in and out, in the Gregorian or
  Ethiopian calendar.
- **PDF report**: Hub → PDF report saves this or last month's totals,
  categories, balances and transactions, drawn by Android's PDF writer.
- **Receipt scan**: Add transaction → Camera or Photo or screenshot. Google
  Play services' on-device text reader fills in amount, payee, date and
  reference for you to check. Amharic text is not read. The photo is deleted
  after reading, and the saved reference stops the bank's alert for the same
  payment from being added twice.

An alert is added without confirmation when its amount and direction are clear
and exactly one non-archived account matches its institution; a reference is
not required. A bank with no account yet gets one, named after the bank. The
one-time scan covers the last 30 days. After each import, the account is
matched to the balance in the newest alert that reports one, with any
difference recorded as a balance adjustment, so older alerts never
double-count an opening balance you typed. Confirming an alert by hand offers
the same match. Alerts with an unclear direction, or for a bank with several
accounts, stay in the SMS review inbox; unrelated or unrecognized messages are
ignored. Deduplication uses the transaction
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
exports and JSON backups (Hub → Backup) are saved to a file you pick with
Android's file picker; they are not encrypted. Restoring a backup replaces the
ledger and plan but keeps device settings and the PIN. Settings → Erase all
data turns SMS tracking off and deletes everything. The optional 4-digit app
lock stores only a salted hash of the PIN; a forgotten PIN means clearing the
app's storage in Android settings.
There is no cloud backup or network sync implemented. SharedPreferences data is
not encrypted. Android backup and device-to-device transfer are disabled
(`allowBackup="false"` plus data-extraction rules that exclude everything). The Ethiopian calendar changes
date labels and monthly summaries; the system date-picker itself remains
Gregorian.
