package com.example.birrwise

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AlertTextTest {
    @Test
    fun pointsLoanOffersAndFailuresMoveNoMoney() {
        listOf(
            "You have received 10 points worth ETB 5.00 from telebirr.",
            "You have scored ETB 20.00 in the telebirr loyalty draw.",
            "You are eligible for a loan of up to ETB 5,000.00. Dial *127#.",
            "Your loan limit is ETB 3,000.00.",
            "Your transfer of ETB 500.00 to Abebe failed. Balance ETB 900.00.",
            "Transaction of ETB 200.00 was unsuccessful due to insufficient balance.",
            "ETB 150.00 ክፍያ አልተሳካም።",
        ).forEach { assertTrue(it, AlertText.movesNoMoney(it)) }
    }

    @Test
    fun realMoneyIsKept() {
        listOf(
            "Your failed transfer of ETB 500.00 has been reversed. Your account has been credited.",
            "Your loan of ETB 2,000.00 has been credited to your account.",
            "You have received ETB 25,000.00 from Abebe Kebede.",
        ).forEach { assertFalse(it, AlertText.movesNoMoney(it)) }
    }
}
