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
}
