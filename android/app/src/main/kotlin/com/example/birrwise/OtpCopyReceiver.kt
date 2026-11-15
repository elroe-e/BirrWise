package com.example.birrwise

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PersistableBundle
import android.widget.Toast

/** Copies a verification code from its notification. Not exported. */
class OtpCopyReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val code = intent.getStringExtra(EXTRA_CODE) ?: return
        val clip = ClipData.newPlainText("Code", code)
        // Keeps the code out of the clipboard preview on Android 13+.
        clip.description.extras = PersistableBundle().apply {
            putBoolean("android.content.extra.IS_SENSITIVE", true)
        }
        context.getSystemService(ClipboardManager::class.java).setPrimaryClip(clip)
        context.getSystemService(NotificationManager::class.java).cancel(OtpNotifier.NOTIFICATION_ID)
        // Android 13+ confirms the copy itself.
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            val amharic = context.getSharedPreferences(BankSmsInbox.PREFERENCES, Context.MODE_PRIVATE)
                .getString(BankSmsInbox.LANGUAGE_KEY, "en") == "am"
            Toast.makeText(context, if (amharic) "ኮዱ ተቀድቷል" else "Code copied", Toast.LENGTH_SHORT).show()
        }
    }

    companion object {
        const val EXTRA_CODE = "code"
    }
}
