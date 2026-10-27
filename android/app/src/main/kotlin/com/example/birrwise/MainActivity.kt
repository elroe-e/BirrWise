package com.example.birrwise

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var permissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "smsPermissions" -> result.success(permissionStatus())
                    "requestSmsPermissions" -> requestSmsPermissions(result)
                    "readBankInbox" -> readBankInbox(
                        call.argument<Number>("sinceMillis")?.toLong() ?: 0L,
                        result,
                    )
                    "readIncomingBankSms" -> readIncomingBankSms(result)
                    "clearIncomingBankSms" -> clearIncomingBankSms(
                        call.argument<List<String>>("ids"),
                        result,
                    )
                    "setSmsAutomationEnabled" -> {
                        val enabled = call.argument<Boolean>("enabled")
                            ?: run {
                                result.error("invalid_argument", "Missing enabled value.", null)
                                return@setMethodCallHandler
                            }
                        try {
                            setSmsAutomationEnabled(enabled)
                            result.success(null)
                        } catch (error: RuntimeException) {
                            result.error(
                                "sms_settings_failed",
                                "Could not update the SMS automation setting.",
                                error.message,
                            )
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun permissionStatus(): Map<String, Boolean> = mapOf(
        "read" to hasPermission(Manifest.permission.READ_SMS),
        "receive" to hasPermission(Manifest.permission.RECEIVE_SMS),
    )

    private fun hasPermission(permission: String): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
            checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED

    private fun requestSmsPermissions(result: MethodChannel.Result) {
        if (hasPermission(Manifest.permission.READ_SMS) &&
            hasPermission(Manifest.permission.RECEIVE_SMS)
        ) {
            result.success(permissionStatus())
            return
        }
        if (permissionResult != null) {
            result.error("permission_in_progress", "An SMS permission request is already active.", null)
            return
        }
        permissionResult = result
        requestPermissions(
            arrayOf(Manifest.permission.READ_SMS, Manifest.permission.RECEIVE_SMS),
            SMS_PERMISSION_REQUEST,
        )
    }

    @Deprecated("Deprecated in the Android SDK")
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != SMS_PERMISSION_REQUEST) return
        permissionResult?.success(permissionStatus())
        permissionResult = null
    }

    private fun readBankInbox(sinceMillis: Long, result: MethodChannel.Result) {
        if (!hasPermission(Manifest.permission.READ_SMS)) {
            result.error("sms_permission", "SMS inbox access was not granted.", null)
            return
        }
        try {
            result.success(BankSmsInbox.read(this, sinceMillis))
        } catch (error: SecurityException) {
            result.error("sms_permission", "Android denied access to the SMS inbox.", null)
        } catch (error: RuntimeException) {
            result.error("sms_read_failed", "BirrWise could not scan the SMS inbox.", error.message)
        }
    }

    private fun readIncomingBankSms(result: MethodChannel.Result) {
        try {
            result.success(BankSmsInbox.readIncoming(this))
        } catch (error: RuntimeException) {
            result.error("sms_read_failed", "BirrWise could not read saved bank alerts.", error.message)
        }
    }

    private fun clearIncomingBankSms(
        ids: List<String>?,
        result: MethodChannel.Result,
    ) {
        try {
            val processedIds = ids?.toSet()
                ?: throw IllegalArgumentException("Missing processed message identifiers.")
            BankSmsInbox.clearIncoming(this, processedIds)
            result.success(null)
        } catch (error: RuntimeException) {
            result.error("sms_read_failed", "BirrWise could not clear processed bank alerts.", error.message)
        }
    }

    private fun setSmsAutomationEnabled(enabled: Boolean) {
        val preferences = getSharedPreferences(BankSmsInbox.PREFERENCES, MODE_PRIVATE)
        val editor = preferences.edit().putBoolean(BankSmsInbox.ENABLED_KEY, enabled)
        if (!enabled) editor.remove(BankSmsInbox.QUEUE_KEY)
        check(editor.commit()) { "Could not save the SMS automation preference." }
    }

    companion object {
        private const val CHANNEL = "birrwise/sms"
        private const val SMS_PERMISSION_REQUEST = 7001
    }
}
