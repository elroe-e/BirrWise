package com.example.birrwise

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import org.json.JSONArray
import org.json.JSONObject
import java.security.MessageDigest

class BankSmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return
        val preferences =
            context.getSharedPreferences(BankSmsInbox.PREFERENCES, Context.MODE_PRIVATE)
        if (!preferences.getBoolean(BankSmsInbox.ENABLED_KEY, false)) return

        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
        if (messages.isEmpty()) return
        val sender = messages.firstOrNull()?.originatingAddress ?: return
        if (BankSmsInbox.trustedInstitution(sender) == null) return
        val body = messages.joinToString(separator = "") { it.messageBody.orEmpty() }
        if (body.isBlank()) return
        // Use the device's receive time, like the SMS inbox does. The
        // service-centre timestamp can differ by minutes (or a time zone),
        // which made the same alert look new when the inbox was rescanned.
        val receivedAt = System.currentTimeMillis()
        val incoming = JSONObject()
            .put("id", "incoming:${fingerprint(sender, receivedAt, body)}")
            .put("sender", sender)
            .put("body", body)
            .put("receivedAt", receivedAt)

        val queue = JSONArray(preferences.getString(BankSmsInbox.QUEUE_KEY, "[]"))
        if ((0 until queue.length()).any { queue.optJSONObject(it)?.optString("id") == incoming.optString("id") }) {
            return
        }
        queue.put(incoming)
        check(preferences.edit().putString(BankSmsInbox.QUEUE_KEY, queue.toString()).commit()) {
            "Could not save an incoming bank alert."
        }
    }

    private fun fingerprint(sender: String, receivedAt: Long, body: String): String {
        val digest = MessageDigest.getInstance("SHA-256")
            .digest("$sender|$receivedAt|$body".toByteArray())
        return digest.joinToString("") { byte -> "%02x".format(byte) }
    }
}
