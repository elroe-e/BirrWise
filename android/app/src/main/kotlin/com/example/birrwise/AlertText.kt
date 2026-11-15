package com.example.birrwise

/**
 * Reads bank-alert wording on the Android side, for code that runs while
 * BirrWise is closed. Keep in step with SmsParser in lib/sms_parser.dart.
 */
internal object AlertText {
    val income = Regex(
        """\b(receiv(?:ed|e)|credit(?:ed)?|deposit(?:ed)?|cash[\s-]*in|top[\s-]*up)\b|ገቢ|ገብቷል|ተቀበሉ|ተቀብለዋል""",
        RegexOption.IGNORE_CASE,
    )
    val expense = Regex(
        """\b(paid|debit(?:ed)?|transferred|sent|withdraw(?:n|al)?|purchase|bought|airtime|cash[\s-]*out|bill[\s-]*pay)\b|ወጪ|ተቀንሷል|ወጥቷል|ከፍለዋል|ተከፍሏል|ተላልፏል""",
        RegexOption.IGNORE_CASE,
    )
    val money = Regex(
        """(?<![A-Za-z])(?:ETB|Birr|Br|ብር)\.?\s*([0-9][0-9,]*(?:\.[0-9]{1,2})?)|([0-9][0-9,]*(?:\.[0-9]{1,2})?)\s*(?:ETB|Birr|Br|ብር)(?![A-Za-z])""",
        RegexOption.IGNORE_CASE,
    )

    // Loyalty points, loan offers and failed transactions move no money. A
    // reversal or refund does, so it is kept.
    private val noMoneyMoved = Regex(
        """\b(?:loyalty|reward|bonus)\s+points?\b|\b[0-9]+\s+points?\b""" +
            """|\byou\s+have\s+scored\b""" +
            """|\b(?:eligible|qualif(?:y|ied)|pre-?approved)\b.{0,40}\bloans?\b""" +
            """|\bloan\s+limit\b|\bborrow\s+up\s+to\b""" +
            """|\b(?:failed|unsuccessful|declined|rejected)\b|\bnot\s+successful\b""" +
            """|\bcould\s+not\s+be\s+(?:completed|processed)\b""" +
            """|\binsufficient\s+(?:balance|funds)\b|አልተሳካም""",
        RegexOption.IGNORE_CASE,
    )
    private val moneyBack = Regex("""\b(?:revers(?:ed|al)|refund(?:ed)?)\b""", RegexOption.IGNORE_CASE)

    /** True for alerts that look like money but move none. */
    fun movesNoMoney(body: String) =
        noMoneyMoved.containsMatchIn(body) && !moneyBack.containsMatchIn(body)

    // Messages that deliver a code, and promotions, are not transactions.
    val codeDelivery = Regex(
        """\b(?:otp|one[\s-]?time[\s-]?(?:password|pin|code)|verification\s+code)\b""" +
            """|\b(?:pin|password|passcode|security\s+code)\s*(?:is|:)?\s*[0-9]{4,8}\b""",
        RegexOption.IGNORE_CASE,
    )
    private val promo = Regex("""\b(?:promo|promotional|promotion)\b""", RegexOption.IGNORE_CASE)

    // The amount rules SmsParser uses to pick the transaction amount.
    private const val NUMBER = """([0-9][0-9,]*(?:\.[0-9]{1,2})?)"""
    private val moneyBefore = Regex(
        """(?<![A-Za-z])(?:ETB|Birr|Br|ብር)\.?\s*$NUMBER""",
        RegexOption.IGNORE_CASE,
    )
    private val moneyAfter = Regex(
        """(?<![0-9/:.\-])([0-9][0-9,]*\.[0-9]{2})\s*(?:ETB|Birr|Br)(?![A-Za-z])""" +
            """|(?<![0-9/:.\-])([0-9][0-9,]*(?:\.[0-9]{1,2})?)\s*ብር""",
        RegexOption.IGNORE_CASE,
    )
    private val balanceLabel = Regex("""\b(balance|bal|remaining|available)\b|ቀሪ""")
    private val feeLabel = Regex("""\b(charge|fee|vat|tax|commission|limit)\b""")

    /** True for money in, false for money out, null when the wording is unclear. */
    fun isIncome(body: String): Boolean? {
        val incoming = income.containsMatchIn(body)
        return if (incoming == expense.containsMatchIn(body)) null else incoming
    }

    /** The transaction amount as written in the alert, or null if it is not a transaction. */
    fun mainAmount(body: String): String? {
        if (codeDelivery.containsMatchIn(body) || movesNoMoney(body)) return null
        if (isIncome(body) == null && promo.containsMatchIn(body)) return null
        val values = (moneyBefore.findAll(body) + moneyAfter.findAll(body))
            .mapNotNull { match ->
                val group = match.groups[1] ?: match.groups[2] ?: return@mapNotNull null
                val prefix = body.substring(0, match.range.first).lowercase()
                Triple(group.range.first, group.value, prefix.takeLast(45))
            }
            .distinctBy { it.first }
            .sortedBy { it.first }
        return values.firstOrNull { (_, _, label) ->
            !balanceLabel.containsMatchIn(label) && !feeLabel.containsMatchIn(label)
        }?.second
    }
}
