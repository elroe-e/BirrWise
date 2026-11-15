package com.example.birrwise

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class TxNotifierTest {
    @Test
    fun picksTheTransactionAmountNotTheFeeOrBalance() {
        assertEquals(
            "Paid ETB 450.00" to "CBE",
            TxNotifier.message(false, "CBE", "You paid ETB 450.00 to Kaldis. Fee ETB 5.00. Balance ETB 1,200.00."),
        )
        assertEquals(
            "Received ETB 25,000.00" to "Telebirr",
            TxNotifier.message(
                false,
                "Telebirr",
                "You have received ETB 25,000.00 from Abebe Kebede. Your balance is ETB 31,200.50.",
            ),
        )
    }

    @Test
    fun amharicAlertsAndText() {
        assertEquals(
            "ገቢ፦ 28,500.00 ብር" to "CBE",
            TxNotifier.message(true, "CBE", "ሒሳብ ቁጥር 1000****4521 በ 28,500.00 ብር ገቢ ሆኗል። ቀሪ ሒሳብ፡ 46,740.00 ብር።"),
        )
    }

    @Test
    fun unclearDirectionAsksForReview() {
        assertEquals(
            "New alert from Awash" to "Open BirrWise to review it",
            TxNotifier.message(false, "Awash", "ETB 90.00 transaction ref AW12345"),
        )
    }

    @Test
    fun nonTransactionsGetNoNotification() {
        assertNull(TxNotifier.message(false, "CBE", "Your balance is ETB 1,000.00."))
        assertNull(TxNotifier.message(false, "CBE", "Your OTP is 442211 for ETB 10.00."))
        assertNull(TxNotifier.message(false, "CBE", "Promo! Claim ETB 500 today."))
        assertNull(TxNotifier.message(false, "Telebirr", "Your loan limit is ETB 3,000.00."))
    }
}
