package com.example.birrwise

import android.content.Context
import android.provider.Telephony
import org.json.JSONArray

internal object BankSmsInbox {
    const val PREFERENCES = "birrwise_sms_bridge"
    const val ENABLED_KEY = "automation_enabled"
    const val QUEUE_KEY = "incoming_bank_sms"

    // Keep in sync with SmsParser._trustedSenders on the Dart side.
    private val trustedSenders = mapOf(
        "127" to "telebirr",
        "telebirr" to "telebirr",
        "telebirrsc" to "telebirr",
        "cbe" to "cbe",
        "cbebirr" to "cbe",
        "awash" to "awash",
        "awashbank" to "awash",
        "awashbanksc" to "awash",
        "boa" to "boa",
        "abyssinia" to "boa",
        "bankofabyssinia" to "boa",
        "dashen" to "dashen",
        "dashenbank" to "dashen",
    )

    fun trustedInstitution(sender: String?): String? {
        val normalized =
            sender.orEmpty().lowercase().filter { it.isLetterOrDigit() }
        return trustedSenders[normalized]
    }

    /** Reads trusted-sender messages received at or after [sinceMillis]. */
    fun read(context: Context, sinceMillis: Long): List<Map<String, Any>> {
        val rows = mutableListOf<Map<String, Any>>()
        val projection = arrayOf(
            Telephony.Sms._ID,
            Telephony.Sms.ADDRESS,
            Telephony.Sms.BODY,
            Telephony.Sms.DATE,
        )
        val cursor = context.contentResolver.query(
            Telephony.Sms.Inbox.CONTENT_URI,
            projection,
            "${Telephony.Sms.DATE} >= ?",
            arrayOf(sinceMillis.toString()),
            "${Telephony.Sms.DATE} ASC",
        ) ?: throw IllegalStateException("Android returned no SMS inbox cursor.")
        cursor.use {
            val idIndex = cursor.getColumnIndexOrThrow(Telephony.Sms._ID)
            val senderIndex = cursor.getColumnIndexOrThrow(Telephony.Sms.ADDRESS)
            val bodyIndex = cursor.getColumnIndexOrThrow(Telephony.Sms.BODY)
            val dateIndex = cursor.getColumnIndexOrThrow(Telephony.Sms.DATE)
            while (cursor.moveToNext()) {
                val sender = cursor.getString(senderIndex) ?: continue
                if (trustedInstitution(sender) == null) continue
                rows.add(
                    mapOf(
                        "id" to "inbox:${cursor.getLong(idIndex)}",
                        "sender" to sender,
                        "body" to (cursor.getString(bodyIndex) ?: ""),
                        "receivedAt" to cursor.getLong(dateIndex),
                    ),
                )
            }
        }
        return rows
    }

    fun readIncoming(context: Context): List<Map<String, Any>> {
        val preferences = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
        val queued = JSONArray(preferences.getString(QUEUE_KEY, "[]"))
        val messages = (0 until queued.length()).mapNotNull { index ->
            val row = queued.optJSONObject(index) ?: return@mapNotNull null
            mapOf(
                "id" to row.optString("id"),
                "sender" to row.optString("sender"),
                "body" to row.optString("body"),
                "receivedAt" to row.optLong("receivedAt"),
            )
        }
        return messages
    }

    fun clearIncoming(context: Context, processedIds: Set<String>) {
        val preferences = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
        val queued = JSONArray(preferences.getString(QUEUE_KEY, "[]"))
        val remaining = JSONArray()
        for (index in 0 until queued.length()) {
            val row = queued.optJSONObject(index) ?: continue
            if (row.optString("id") !in processedIds) remaining.put(row)
        }
        val editor = preferences.edit()
        if (remaining.length() == 0) editor.remove(QUEUE_KEY) else editor.putString(QUEUE_KEY, remaining.toString())
        check(editor.commit()) {
            "Could not clear processed SMS alerts."
        }
    }
}
