package com.example.birrwise

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ShopPaymentsTest {
    @Test
    fun incomingAlertGivesItsAmounts() {
        assertEquals(
            listOf("25000.00", "31200.50"),
            ShopPayments.incomingAmounts(
                "You have received ETB 25,000.00 from Abebe Kebede. " +
                    "Your transaction number is CJC12ABC34. Your balance is ETB 31,200.50.",
            ),
        )
        assertEquals(
            listOf("28500.00", "46740.00"),
            ShopPayments.incomingAmounts(
                "ሒሳብ ቁጥር 1000****4521 በ 28,500.00 ብር ገቢ ሆኗል። ቀሪ ሒሳብ፡ 46,740.00 ብር።",
            ),
        )
    }

    @Test
    fun spendingAndUnclearAlertsAreNeverSent() {
        assertNull(ShopPayments.incomingAmounts("You have paid ETB 250.00 to Tomoca Coffee."))
        assertNull(ShopPayments.incomingAmounts("ለ ቶሞካ ካፌ 250.00 ብር ተከፍሏል።"))
        assertNull(ShopPayments.incomingAmounts("Transaction of ETB 300.00 processed."))
    }
}
