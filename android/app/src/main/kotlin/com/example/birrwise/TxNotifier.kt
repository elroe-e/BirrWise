package com.example.birrwise

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.os.Build

/** Posts a notification for each bank alert, from the SMS receiver. */
internal object TxNotifier {
    private const val CHANNEL_ID = "transactions"

    fun onAlert(context: Context, institution: String, body: String, id: String, receivedAt: Long) {
        val prefs = context.getSharedPreferences(BankSmsInbox.PREFERENCES, Context.MODE_PRIVATE)
        if (!prefs.getBoolean(BankSmsInbox.TX_ALERTS_KEY, false)) return
        val name = BankSmsInbox.displayName(institution)
        if (prefs.getStringSet(BankSmsInbox.IGNORED_KEY, null).orEmpty().contains(name)) return
        val amharic = prefs.getString(BankSmsInbox.LANGUAGE_KEY, "en") == "am"
        val (title, text) = message(amharic, name, body) ?: return

        val manager = context.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    if (amharic) "ግብይቶች" else "Transactions",
                    NotificationManager.IMPORTANCE_DEFAULT,
                ),
            )
        }
        if (!manager.areNotificationsEnabled()) return
        val hidden = builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_birrwise)
            .setContentTitle("BirrWise")
            .setContentText(if (amharic) "አዲስ የባንክ መልዕክት" else "New bank alert")
            .build()
        val notification = builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_birrwise)
            .setContentTitle(title)
            .setContentText(text)
            .setWhen(receivedAt)
            .setShowWhen(true)
            .setAutoCancel(true)
            .setContentIntent(openApp(context))
            .setVisibility(Notification.VISIBILITY_PRIVATE)
            .setPublicVersion(hidden)
            .build()
        manager.notify(id.hashCode(), notification)
    }

    /** Title and text for an alert, or null when it is not a transaction. */
    fun message(amharic: Boolean, name: String, body: String): Pair<String, String>? {
        val amount = AlertText.mainAmount(body) ?: return null
        return when (AlertText.isIncome(body)) {
            true -> (if (amharic) "ገቢ፦ $amount ብር" else "Received ETB $amount") to name
            false -> (if (amharic) "ወጪ፦ $amount ብር" else "Paid ETB $amount") to name
            null -> (if (amharic) "ከ$name አዲስ መልዕክት" else "New alert from $name") to
                (if (amharic) "ለክለሳ BirrWiseን ይክፈቱ" else "Open BirrWise to review it")
        }
    }

    fun builder(context: Context, channelId: String): Notification.Builder =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, channelId)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }

    fun openApp(context: Context): PendingIntent? {
        val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?: return null
        return PendingIntent.getActivity(
            context,
            0,
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
    }
}
