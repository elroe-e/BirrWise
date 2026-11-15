# BirrWise 1.4.0 plan: features from Gebeta SMS

Status: waiting for approval. Nothing below is built yet, except step 0.

## What stays out

| Left out | Why |
|---|---|
| Speaking the amount aloud | You said no. |
| Google sign-in and cloud sync | You said no. |
| Suqee shop mode (branches, items) | You said no. |
| Ads, subscriptions, vouchers, referrals | In Gebeta these sell voice credits. They need an ad account and a payment server, and would put ads in your own app. Say so if you want them. |
| Sending OTP codes to a server | Gebeta does this. BirrWise keeps codes on the phone. |
| Gebeta's code, images and recordings | They belong to Gebeta. Everything here is written new. |
| Kaafi, Siinqee and Abay banks | I need one real SMS from each to read them correctly. Send them any time and I'll add them. |

## Rules for every step

- BirrWise stays offline. No step adds a network request.
- Each new feature has its own switch in Settings.
- Each step ends with tests passing and its own commit, so any step can be dropped without touching the others.
- No new Flutter packages. New native code goes next to the existing Kotlin files.

## Steps, in build order

### 0. Fix dropped Coopay and BOA alerts (done, commit 13901e2)
Alerts from the senders `COOPayEBIRR` and `Boa Bank Of Abyssinia` were silently ignored. Fixed and tested.

### 1. Skip promo, loan-offer and failed-transaction messages
- **What you get:** messages like "you earned 1 point", "you are eligible for a loan" or "transaction failed" never become transactions or notifications.
- **How:** one list of ignore phrases in `lib/sms_parser.dart`, and the same list in a new Kotlin file `AlertText.kt`. `AlertText.kt` also takes over the money-in and money-out wording that `ShopPayments.kt` holds today, so Kotlin has one copy.
- **Care:** a reversal or refund is real money and is not filtered.
- **Tests:** one sample message per phrase, on both the Dart and Kotlin sides.

### 2. Notification for each transaction
- **What you get:** when a bank alert arrives, even with BirrWise closed, a notification such as "Received ETB 500.00 · CBE" with the normal notification sound. Tapping it opens BirrWise.
- **How:**
  - New `TxNotifier.kt`, called from `BankSmsReceiver.kt`, using `AlertText.kt` for the amount and direction.
  - New permission `POST_NOTIFICATIONS`, asked for when you turn the switch on.
  - Dart tells Kotlin which banks you unticked, so those never notify.
- **Settings:** "Notify me about transactions", off until you turn it on.
- **Privacy:** on a locked screen Android shows only "New bank alert" if you hide sensitive notifications.
- **Limit:** if the amount or direction is unclear, the notification says "New alert from CBE to review" instead of guessing.

### 3. OTP code with one-tap copy
- **What you get:** when an SMS with a verification code arrives, a notification shows the code with a Copy button. It disappears after 5 minutes.
- **How:** new `OtpNotifier.kt` and a small `OtpCopyReceiver.kt`. The code is never saved and never leaves the phone.
- **Settings:** "Show verification codes", off by default.
- **Decision I made:** it works for codes from any sender, not only banks, because most codes come from other services. BirrWise reads those messages only to find the code and keeps nothing.

### 4. Calendar view
- **What you get:** a month grid in Insights. Each day shows money in and money out. Tapping a day lists its transactions.
- **How:** one new file `lib/calendar_view.dart`, built from plain Flutter widgets. It follows your Ethiopian or Gregorian calendar setting through the existing `ethiopian_date.dart`.
- **Tests:** day totals, and month boundaries in both calendars.

### 5. PDF report
- **What you get:** Hub → "PDF report" saves a monthly report: totals, spending by category and the transaction list. You pick where to save it, the same way as CSV.
- **How:** Android's built-in PDF writer in a new `PdfReport.kt`. It needs no package and prints Amharic correctly with the phone's own fonts.
- **Limit:** plain layout (text and tables, no charts).

### 6. Receipt scan
- **What you get:** in Add transaction, "Scan receipt" lets you take a photo or pick a screenshot. BirrWise reads the amount, date and reference and fills in the form. You always confirm before it is saved.
- **How:** Google's on-device text reader through Play services, in a new `ReceiptScanner.kt`. The found text goes through the same amount rules as SMS.
- **Cost:** adds under 1 MB to the app. The first scan needs Google Play services to fetch the reading model once; after that it works offline. Photos are not kept.
- **Limits:** reads printed English text well; Amharic text is not read. QR codes are skipped, because CBE's QR only links to a web page.

### 7. Wrap up
- Update the README and the in-app privacy policy for notifications, OTP and receipt scan.
- Version 1.4.0, build the two APKs, publish the GitHub release.

## What I can and can't check

- I run the Dart tests, the Kotlin unit tests and a full release build after every step.
- I can't test on a real phone. Notifications, the OTP copy button, the PDF file and the camera scan need you to try them once on your phone before the release is published. I'll give you a short checklist with the test APK.

## Decisions for you

1. Leave out ads, subscriptions, vouchers and referrals? (My plan: yes.)
2. OTP codes from any sender, or bank senders only? (My plan: any sender.)
3. Receipt scan through Play services, accepting the one-time model download? (My plan: yes.)
