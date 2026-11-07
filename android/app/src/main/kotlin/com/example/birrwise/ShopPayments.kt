package com.example.birrwise

import android.content.Context
import android.util.Base64
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest

/**
 * Lets the shop's staff console see that a customer's money arrived. Runs in
 * the SMS receiver, so it works while BirrWise is closed. Only incoming-money
 * alerts are sent, as amounts; the shop's server keeps them only when they
 * match a payment the staff said they were waiting for.
 */
internal object ShopPayments {
    private const val PREFERENCES = "birrwise_shop_link"
    private const val LINK_KEY = "link"
    private const val PENDING_KEY = "pending"
    private const val MAX_AGE_MILLIS = 2 * 24 * 60 * 60 * 1000L

    // Same words BirrWise's parser uses for money in and money out.
    private val income = Regex(
        """\b(receiv(?:ed|e)|credit(?:ed)?|deposit(?:ed)?)\b|ገቢ|ገብቷል|ተቀበሉ|ተቀብለዋል""",
        RegexOption.IGNORE_CASE,
    )
    private val expense = Regex(
        """\b(paid|debit(?:ed)?|transferred|sent|withdraw(?:n|al)?|purchase|bought)\b|ወጪ|ተቀንሷል|ከፍለዋል|ተከፍሏል|ተላልፏል""",
        RegexOption.IGNORE_CASE,
    )
    private val money = Regex(
        """(?<![A-Za-z])(?:ETB|Birr|Br|ብር)\.?\s*([0-9][0-9,]*(?:\.[0-9]{1,2})?)|([0-9][0-9,]*(?:\.[0-9]{1,2})?)\s*(?:ETB|Birr|Br|ብር)(?![A-Za-z])""",
        RegexOption.IGNORE_CASE,
    )

    fun isLinked(context: Context) = prefs(context).getString(LINK_KEY, null) != null

    /** Saves the code from the shop's Payments page. Returns false if it is not a valid code. */
    fun link(context: Context, code: String): Boolean {
        val json = try {
            JSONObject(String(Base64.decode(code.trim(), Base64.DEFAULT)))
        } catch (error: Exception) {
            return false
        }
        val url = json.optString("u")
        if (!url.startsWith("https://") || json.optString("a").isEmpty() || json.optString("k").length < 32) {
            return false
        }
        return prefs(context).edit().putString(LINK_KEY, json.toString()).commit()
    }

    fun unlink(context: Context) {
        prefs(context).edit().clear().commit()
    }

    /** Amounts in an incoming-money alert, or null if it is not one. */
    fun incomingAmounts(body: String): List<String>? {
        if (!income.containsMatchIn(body) || expense.containsMatchIn(body)) return null
        // shortcut: every amount is sent, the balance included; a balance that
        // equals a waiting payment could confirm it, which is very unlikely.
        val amounts = money.findAll(body)
            .mapNotNull { (it.groups[1] ?: it.groups[2])?.value?.replace(",", "") }
            .distinct().take(20).toList()
        return amounts.ifEmpty { null }
    }

    /** Queues the alert if it is incoming money and tries to send it now. */
    fun onAlert(context: Context, institution: String, body: String, receivedAt: Long) {
        if (!isLinked(context)) return
        val amounts = incomingAmounts(body) ?: return
        val key = MessageDigest.getInstance("SHA-256").digest("$institution|$body".toByteArray())
            .joinToString("") { "%02x".format(it) }
        val pending = JSONArray(prefs(context).getString(PENDING_KEY, "[]"))
        pending.put(
            JSONObject()
                .put("p_alert_key", key)
                .put("p_institution", institution)
                .put("p_amounts", JSONArray(amounts))
                .put("receivedAt", receivedAt),
        )
        prefs(context).edit().putString(PENDING_KEY, pending.toString()).commit()
        flush(context)
    }

    /** Sends queued alerts; those that fail for lack of network wait for the next try. */
    @Synchronized
    fun flush(context: Context) {
        val link = prefs(context).getString(LINK_KEY, null)?.let(::JSONObject) ?: return
        val pending = JSONArray(prefs(context).getString(PENDING_KEY, "[]"))
        val left = JSONArray()
        val now = System.currentTimeMillis()
        for (i in 0 until pending.length()) {
            val item = pending.getJSONObject(i)
            val receivedAt = item.getLong("receivedAt")
            if (now - receivedAt > MAX_AGE_MILLIS) continue
            val body = JSONObject(item.toString())
                .put("p_key", link.getString("k"))
                .put("p_received_at", isoUtc(receivedAt))
            body.remove("receivedAt")
            val status = try {
                post(link, body.toString())
            } catch (error: Exception) {
                0
            }
            // Keep it for a retry only when the shop could not be reached.
            if (status == 0 || status >= 500) left.put(item)
        }
        prefs(context).edit().putString(PENDING_KEY, left.toString()).commit()
    }

    private fun post(link: JSONObject, json: String): Int {
        val connection = URL("${link.getString("u")}/rest/v1/rpc/claim_shop_payment")
            .openConnection() as HttpURLConnection
        try {
            connection.requestMethod = "POST"
            connection.connectTimeout = 8_000
            connection.readTimeout = 8_000
            connection.doOutput = true
            connection.setRequestProperty("content-type", "application/json")
            connection.setRequestProperty("apikey", link.getString("a"))
            connection.setRequestProperty("authorization", "Bearer ${link.getString("a")}")
            connection.outputStream.use { it.write(json.toByteArray()) }
            return connection.responseCode
        } finally {
            connection.disconnect()
        }
    }

    private fun isoUtc(millis: Long): String =
        java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", java.util.Locale.US)
            .apply { timeZone = java.util.TimeZone.getTimeZone("UTC") }
            .format(java.util.Date(millis))

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
}
