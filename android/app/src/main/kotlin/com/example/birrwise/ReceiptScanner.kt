package com.example.birrwise

import android.content.Context
import android.net.Uri
import androidx.core.content.FileProvider
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import java.io.File

/**
 * Reads the text of a receipt photo or screenshot on the phone, with Google's
 * text reader from Play services. Nothing is uploaded and photos are not kept.
 */
internal object ReceiptScanner {
    /** A fresh file for the camera app to write the photo to, as a private content URI. */
    fun photoTarget(context: Context): Pair<File, Uri> {
        val folder = File(context.cacheDir, "receipts").apply { mkdirs() }
        val file = File(folder, "receipt.jpg").apply { delete() }
        val uri = FileProvider.getUriForFile(context, "${context.packageName}.receipts", file)
        return file to uri
    }

    /** Reads [uri] and calls back with its text, or with an error message. */
    fun read(context: Context, uri: Uri, done: (text: String?, error: String?) -> Unit) {
        val image = try {
            InputImage.fromFilePath(context, uri)
        } catch (error: Exception) {
            done(null, error.message ?: "Could not open the image.")
            return
        }
        val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
        recognizer.process(image)
            .addOnSuccessListener { done(it.text, null) }
            .addOnFailureListener { done(null, it.message ?: "Could not read the image.") }
            .addOnCompleteListener { recognizer.close() }
    }
}
