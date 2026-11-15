package com.example.birrwise

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.drawable.Icon
import android.os.Build

/**
 * Shows a verification code from any SMS with a Copy button. The code lives
 * only in the notification: it is never saved, logged or sent anywhere.
 */
internal object OtpNotifier {
    private const val CHANNEL_ID = "codes"
    private const val SHOW_MILLIS = 5 * 60 * 1000L

    // One at a time: a newer code replaces the older one.
    const val NOTIFICATION_ID = 7100

    private val asksForCode = Regex(
        """\b(?:otp|one[\s-]?time|verification|verify|passcode|security\s+code|login\s+code|code)\b|ኮድ|የማረጋገጫ""",
        RegexOption.IGNORE_CASE,
    )
    private val codeFirst = Regex("""\b(?:[A-Z]-)?([0-9]{4,8})\s+is\s+your\b""", RegexOption.IGNORE_CASE)
    private val codeAfterLabel = Regex(
        """(?:\b(?:code|otp|passcode|password|pin)\b|ኮድ)[^0-9\n]{0,15}([0-9]{4,8})(?![0-9])""",
        RegexOption.IGNORE_CASE,
    )
    private val codeAfterIs = Regex("""\bis\s+([0-9]{4,8})(?![0-9])""", RegexOption.IGNORE_CASE)

    /** The code in a verification message, or null. */
    fun code(body: String): String? {
        if (!asksForCode.containsMatchIn(body)) return null
        // A bank alert that moved money, whatever codes it mentions.
        if (AlertText.isIncome(body) != null && AlertText.mainAmount(body) != null) return null
        return (codeFirst.find(body) ?: codeAfterLabel.find(body) ?: codeAfterIs.find(body))?.groupValues?.get(1)
    }

    fun onMessage(context: Context, sender: String, body: String) {
        val prefs = context.getSharedPreferences(BankSmsInbox.PREFERENCES, Context.MODE_PRIVATE)
        if (!prefs.getBoolean(BankSmsInbox.OTP_ALERTS_KEY, false)) return
        val code = code(body) ?: return
        val amharic = prefs.getString(BankSmsInbox.LANGUAGE_KEY, "en") == "am"
        val from = BankSmsInbox.trustedInstitution(sender)?.let(BankSmsInbox::displayName) ?: sender

        val manager = context.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    if (amharic) "የማረጋገጫ ኮዶች" else "Verification codes",
                    NotificationManager.IMPORTANCE_HIGH,
                ),
            )
        }
        if (!manager.areNotificationsEnabled()) return
        val copy = PendingIntent.getBroadcast(
            context,
            NOTIFICATION_ID,
            Intent(context, OtpCopyReceiver::class.java).putExtra(OtpCopyReceiver.EXTRA_CODE, code),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val hidden = TxNotifier.builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_birrwise)
            .setContentTitle(if (amharic) "የማረጋገጫ ኮድ" else "Verification code")
            .setContentText(from)
            .build()
        val builder = TxNotifier.builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_birrwise)
            .setContentTitle(code)
            .setContentText(if (amharic) "ከ$from · ለመቅዳት ይንኩ" else "From $from · tap to copy")
            .setContentIntent(copy)
            .addAction(Notification.Action.Builder(null as Icon?, if (amharic) "ቅዳ" else "Copy", copy).build())
            .setAutoCancel(true)
            .setVisibility(Notification.VISIBILITY_PRIVATE)
            .setPublicVersion(hidden)
        // shortcut: Android 7 keeps the code until it is swiped away; the
        // timeout needs Android 8.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) builder.setTimeoutAfter(SHOW_MILLIS)
        manager.notify(NOTIFICATION_ID, builder.build())
    }
}
