package com.example.birrwise

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class OtpNotifierTest {
    @Test
    fun findsTheCodeInVerificationMessages() {
        assertEquals("442211", OtpNotifier.code("Your OTP is 442211. Do not share it with anyone."))
        assertEquals("123456", OtpNotifier.code("G-123456 is your Google verification code."))
        assertEquals("8841", OtpNotifier.code("Your telebirr verification code is 8841."))
        assertEquals("5521", OtpNotifier.code("የማረጋገጫ ኮድዎ 5521 ነው።"))
        assertEquals("1234", OtpNotifier.code("Use code 1234 to confirm your payment of ETB 500.00."))
        assertEquals("907311", OtpNotifier.code("Your OTP for the transfer of ETB 500.00 is 907311."))
    }

    @Test
    fun bankAlertsAndOrdinaryMessagesHaveNoCode() {
        assertNull(OtpNotifier.code("You paid ETB 450.00 to Kaldis. Transaction code 12345678."))
        assertNull(OtpNotifier.code("Never share your PIN with anyone. You received ETB 30.00."))
        assertNull(OtpNotifier.code("Your account 1000123456 has been credited with ETB 50.00."))
        assertNull(OtpNotifier.code("Your code for account 10001234567 is ready."))
        assertNull(OtpNotifier.code("See you at 1430 tomorrow."))
    }
}
