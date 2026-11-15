package com.example.birrwise

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var permissionResult: MethodChannel.Result? = null
    private var notificationResult: MethodChannel.Result? = null
    private var documentResult: MethodChannel.Result? = null
    private var documentContent: String? = null
    private var documentPdf: List<Map<String, Any?>>? = null
    private var receiptResult: MethodChannel.Result? = null
    private var receiptPhoto: java.io.File? = null

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
                    "playSound" -> result.success(
                        SoundPlayer.play(call.argument<String>("name").orEmpty()),
                    )
                    "saveDocument" -> saveDocument(
                        call.argument<String>("name") ?: "BirrWise.txt",
                        call.argument<String>("mimeType") ?: "text/plain",
                        call.argument<String>("content").orEmpty(),
                        result,
                    )
                    "openDocument" -> openDocument(result)
                    "scanReceipt" -> scanReceipt(call.argument<String>("source") == "camera", result)
                    "savePdf" -> savePdf(
                        call.argument<String>("name") ?: "BirrWise.pdf",
                        call.argument<List<Map<String, Any?>>>("blocks").orEmpty(),
                        result,
                    )
                    "linkShop" -> result.success(
                        ShopPayments.link(this, call.argument<String>("code").orEmpty()),
                    )
                    "unlinkShop" -> {
                        ShopPayments.unlink(this)
                        result.success(null)
                    }
                    "shopLinked" -> result.success(ShopPayments.isLinked(this))
                    "flushShop" -> {
                        Thread { ShopPayments.flush(applicationContext) }.start()
                        result.success(null)
                    }
                    "requestNotifications" -> requestNotifications(result)
                    "setAlertSettings" -> {
                        getSharedPreferences(BankSmsInbox.PREFERENCES, MODE_PRIVATE).edit()
                            .putBoolean(BankSmsInbox.TX_ALERTS_KEY, call.argument<Boolean>("transactions") == true)
                            .putBoolean(BankSmsInbox.OTP_ALERTS_KEY, call.argument<Boolean>("otp") == true)
                            .putString(BankSmsInbox.LANGUAGE_KEY, call.argument<String>("language") ?: "en")
                            .putStringSet(
                                BankSmsInbox.IGNORED_KEY,
                                call.argument<List<String>>("ignored").orEmpty().toSet(),
                            )
                            .apply()
                        result.success(null)
                    }
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

    /** Asks to show notifications (Android 13+). Returns whether they are allowed. */
    private fun requestNotifications(result: MethodChannel.Result) {
        val manager = getSystemService(android.app.NotificationManager::class.java)
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            hasPermission(Manifest.permission.POST_NOTIFICATIONS)
        ) {
            result.success(manager.areNotificationsEnabled())
            return
        }
        if (notificationResult != null) {
            result.error("permission_in_progress", "A notification permission request is already active.", null)
            return
        }
        notificationResult = result
        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), NOTIFICATION_PERMISSION_REQUEST)
    }

    @Deprecated("Deprecated in the Android SDK")
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == NOTIFICATION_PERMISSION_REQUEST) {
            notificationResult?.success(
                grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED,
            )
            notificationResult = null
            return
        }
        if (requestCode != SMS_PERMISSION_REQUEST) return
        permissionResult?.success(permissionStatus())
        permissionResult = null
    }

    /** Lets the person pick where to save, then writes [content] there. */
    private fun saveDocument(
        name: String,
        mimeType: String,
        content: String,
        result: MethodChannel.Result,
    ) {
        if (!startDocumentRequest(result)) return
        documentContent = content
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT)
            .addCategory(Intent.CATEGORY_OPENABLE)
            .setType(mimeType)
            .putExtra(Intent.EXTRA_TITLE, name)
        startActivityForResult(intent, SAVE_DOCUMENT_REQUEST)
    }

    /** Lets the person pick where to save, then draws the report there as a PDF. */
    private fun savePdf(name: String, blocks: List<Map<String, Any?>>, result: MethodChannel.Result) {
        if (!startDocumentRequest(result)) return
        documentPdf = blocks
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT)
            .addCategory(Intent.CATEGORY_OPENABLE)
            .setType("application/pdf")
            .putExtra(Intent.EXTRA_TITLE, name)
        startActivityForResult(intent, SAVE_DOCUMENT_REQUEST)
    }

    /** Takes or picks a receipt image and returns its text, or null if cancelled. */
    private fun scanReceipt(camera: Boolean, result: MethodChannel.Result) {
        if (receiptResult != null) {
            result.error("receipt_in_progress", "A receipt scan is already open.", null)
            return
        }
        val intent = if (camera) {
            val (file, uri) = ReceiptScanner.photoTarget(this)
            receiptPhoto = file
            Intent(android.provider.MediaStore.ACTION_IMAGE_CAPTURE)
                .putExtra(android.provider.MediaStore.EXTRA_OUTPUT, uri)
                .addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION or Intent.FLAG_GRANT_READ_URI_PERMISSION)
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            Intent(android.provider.MediaStore.ACTION_PICK_IMAGES)
        } else {
            Intent(Intent.ACTION_GET_CONTENT).addCategory(Intent.CATEGORY_OPENABLE).setType("image/*")
        }
        try {
            startActivityForResult(intent, RECEIPT_REQUEST)
            receiptResult = result
        } catch (error: android.content.ActivityNotFoundException) {
            receiptPhoto = null
            result.error("no_camera", "No app on this phone can take or pick a photo.", null)
        }
    }

    /** Lets the person pick a file and returns its text, or null if cancelled. */
    private fun openDocument(result: MethodChannel.Result) {
        if (!startDocumentRequest(result)) return
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT)
            .addCategory(Intent.CATEGORY_OPENABLE)
            .setType("*/*")
        startActivityForResult(intent, OPEN_DOCUMENT_REQUEST)
    }

    private fun startDocumentRequest(result: MethodChannel.Result): Boolean {
        if (documentResult != null) {
            result.error("document_in_progress", "A file picker is already open.", null)
            return false
        }
        documentResult = result
        return true
    }

    @Deprecated("Deprecated in the Android SDK")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == RECEIPT_REQUEST) {
            val result = receiptResult ?: return
            val photo = receiptPhoto
            receiptResult = null
            receiptPhoto = null
            val uri = when {
                resultCode != Activity.RESULT_OK -> null
                photo != null -> if (photo.length() > 0) Uri.fromFile(photo) else null
                else -> data?.data
            }
            if (uri == null) {
                photo?.delete()
                result.success(null)
                return
            }
            ReceiptScanner.read(this, uri) { text, error ->
                photo?.delete()
                if (error != null) result.error("receipt_failed", "BirrWise could not read that image.", error)
                else result.success(text)
            }
            return
        }
        if (requestCode != SAVE_DOCUMENT_REQUEST && requestCode != OPEN_DOCUMENT_REQUEST) return
        val result = documentResult ?: return
        val content = documentContent
        val pdf = documentPdf
        documentResult = null
        documentContent = null
        documentPdf = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return
        }
        try {
            if (requestCode == SAVE_DOCUMENT_REQUEST) {
                contentResolver.openOutputStream(uri, "wt").use { stream ->
                    checkNotNull(stream) { "Could not open the file." }
                    if (pdf != null) PdfReport.write(pdf, stream) else stream.write(content.orEmpty().toByteArray())
                }
                result.success(true)
            } else {
                val text = contentResolver.openInputStream(uri).use { stream ->
                    checkNotNull(stream) { "Could not open the file." }
                    stream.readBytes().toString(Charsets.UTF_8)
                }
                result.success(text)
            }
        } catch (error: Exception) {
            result.error("document_failed", "BirrWise could not use that file.", error.message)
        }
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
        private const val SAVE_DOCUMENT_REQUEST = 7002
        private const val OPEN_DOCUMENT_REQUEST = 7003
        private const val NOTIFICATION_PERMISSION_REQUEST = 7004
        private const val RECEIPT_REQUEST = 7005
    }
}
