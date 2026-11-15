package com.example.birrwise

import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import android.graphics.pdf.PdfDocument
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import java.io.OutputStream

/**
 * Draws the report lines built by lib/pdf_report.dart into an A4 PDF.
 * Android's own fonts render Amharic, so no font is bundled.
 */
internal object PdfReport {
    private const val WIDTH = 595 // A4 in points
    private const val HEIGHT = 842
    private const val MARGIN = 48f
    private const val GAP = 8f

    private fun paint(size: Float, bold: Boolean = false, color: Int = Color.rgb(28, 27, 23)) =
        TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
            textSize = size
            this.color = color
            typeface = if (bold) Typeface.DEFAULT_BOLD else Typeface.DEFAULT
        }

    private val title = paint(20f, bold = true, color = Color.rgb(27, 67, 50))
    private val sub = paint(10f, color = Color.rgb(95, 91, 80))
    private val heading = paint(13f, bold = true, color = Color.rgb(27, 67, 50))
    private val text = paint(10f)
    private val bold = paint(10f, bold = true)
    private val rule = Paint().apply { color = Color.rgb(236, 231, 221); strokeWidth = 0.8f }

    // Column widths, as shares of the page, for rows of 2, 3 and 4 cells.
    private val columns = mapOf(
        2 to listOf(.65f, .35f),
        3 to listOf(.5f, .2f, .3f),
        4 to listOf(.18f, .4f, .2f, .22f),
    )

    fun write(blocks: List<Map<String, Any?>>, out: OutputStream) {
        val document = PdfDocument()
        val contentWidth = WIDTH - 2 * MARGIN
        var number = 0
        var page: PdfDocument.Page? = null
        var y = 0f
        fun canvas(): Canvas = page!!.canvas
        fun newPage() {
            page?.let(document::finishPage)
            number++
            page = document.startPage(PdfDocument.PageInfo.Builder(WIDTH, HEIGHT, number).create())
            y = MARGIN
        }
        fun layout(value: String, paint: TextPaint, width: Float, right: Boolean = false) =
            StaticLayout.Builder.obtain(value, 0, value.length, paint, width.toInt())
                .setAlignment(if (right) Layout.Alignment.ALIGN_OPPOSITE else Layout.Alignment.ALIGN_NORMAL)
                .build()
        fun draw(layout: StaticLayout, x: Float) {
            canvas().save()
            canvas().translate(MARGIN + x, y)
            layout.draw(canvas())
            canvas().restore()
        }

        try {
            newPage()
            for (block in blocks) {
                val kind = block["k"] as? String ?: continue
                if (kind == "row") {
                    @Suppress("UNCHECKED_CAST")
                    val cells = (block["c"] as? List<String>).orEmpty()
                    val shares = columns[cells.size] ?: continue
                    val paint = if (block["b"] == true) bold else text
                    var x = 0f
                    val placed = cells.mapIndexed { i, cell ->
                        val width = contentWidth * shares[i] - if (i < cells.lastIndex) GAP else 0f
                        val laid = layout(cell, paint, width, right = i == cells.lastIndex) to x
                        x += contentWidth * shares[i]
                        laid
                    }
                    val height = placed.maxOf { it.first.height } + 6f
                    if (y + height > HEIGHT - MARGIN) newPage()
                    y += 3f
                    placed.forEach { (laid, at) -> draw(laid, at) }
                    y += height - 3f
                    canvas().drawLine(MARGIN, y, WIDTH - MARGIN, y, rule)
                } else {
                    val value = block["t"] as? String ?: continue
                    val (paint, before, after) = when (kind) {
                        "title" -> Triple(title, 0f, 4f)
                        "sub" -> Triple(sub, 0f, 8f)
                        "h" -> Triple(heading, 18f, 6f)
                        else -> Triple(text, 4f, 4f)
                    }
                    val laid = layout(value, paint, contentWidth)
                    // A heading never ends a page on its own.
                    val keep = if (kind == "h") 40f else 0f
                    if (y + before + laid.height + after + keep > HEIGHT - MARGIN) newPage() else y += before
                    draw(laid, 0f)
                    y += laid.height + after
                }
            }
            page?.let(document::finishPage)
            document.writeTo(out)
        } finally {
            document.close()
        }
    }
}
