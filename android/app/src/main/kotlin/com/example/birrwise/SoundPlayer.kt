package com.example.birrwise

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import kotlin.math.PI
import kotlin.math.asin
import kotlin.math.cos
import kotlin.math.exp
import kotlin.math.sin
import kotlin.random.Random

/** Short feedback sounds synthesized on the device, so no audio files ship. */
internal object SoundPlayer {
    private const val RATE = 44100

    private data class Tone(
        val frequency: Double,
        val start: Double,
        val end: Double,
        val peak: Double,
        val triangle: Boolean = false,
    )

    fun play(name: String): Boolean {
        val samples = when (name) {
            "chime" -> tones(
                Tone(587.33, 0.0, 0.35, 0.2),
                Tone(880.0, 0.08, 0.55, 0.18, triangle = true),
            )
            "sms" -> tones(
                Tone(739.99, 0.0, 0.22, 0.22),
                Tone(1108.73, 0.12, 0.65, 0.25),
            )
            "goal" -> tones(
                *listOf(587.33, 739.99, 880.0, 1174.66).mapIndexed { i, f ->
                    Tone(f, i * 0.08, i * 0.08 + 0.45, 0.2, triangle = true)
                }.toTypedArray(),
            )
            "cash" -> rustle()
            else -> return false
        }
        Thread { output(samples) }.start()
        return true
    }

    private fun envelope(t: Double, length: Double, peak: Double): Double {
        val attack = 0.02
        return if (t < attack) peak * t / attack
        else peak * exp(-6.0 * (t - attack) / (length - attack))
    }

    private fun tones(vararg tones: Tone): ShortArray {
        val length = tones.maxOf { it.end }
        val out = DoubleArray((length * RATE).toInt())
        for (tone in tones) {
            val from = (tone.start * RATE).toInt()
            val to = minOf((tone.end * RATE).toInt(), out.size)
            for (i in from until to) {
                val t = (i - from).toDouble() / RATE
                val phase = 2 * PI * tone.frequency * t
                val wave = if (tone.triangle) 2 / PI * asin(sin(phase)) else sin(phase)
                out[i] += wave * envelope(t, tone.end - tone.start, tone.peak)
            }
        }
        return toPcm(out)
    }

    /** Band-passed noise around 1.4 kHz, like paper notes being counted. */
    private fun rustle(): ShortArray {
        val length = 0.22
        val out = DoubleArray((length * RATE).toInt())
        val w = 2 * PI * 1400 / RATE
        val alpha = sin(w) / (2 * 3.0)
        val a0 = 1 + alpha
        val b0 = alpha / a0
        val b2 = -alpha / a0
        val a1 = -2 * cos(w) / a0
        val a2 = (1 - alpha) / a0
        var x1 = 0.0; var x2 = 0.0; var y1 = 0.0; var y2 = 0.0
        for (i in out.indices) {
            val x = Random.nextDouble(-1.0, 1.0)
            val y = b0 * x + b2 * x2 - a1 * y1 - a2 * y2
            x2 = x1; x1 = x; y2 = y1; y1 = y
            out[i] = y * envelope(i.toDouble() / RATE, length, 0.5)
        }
        return toPcm(out)
    }

    private fun toPcm(samples: DoubleArray) = ShortArray(samples.size) {
        (samples[it].coerceIn(-1.0, 1.0) * Short.MAX_VALUE).toInt().toShort()
    }

    private fun output(pcm: ShortArray) {
        val track = AudioTrack(
            AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build(),
            AudioFormat.Builder()
                .setSampleRate(RATE)
                .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                .build(),
            pcm.size * 2,
            AudioTrack.MODE_STATIC,
            0,
        )
        try {
            track.write(pcm, 0, pcm.size)
            track.play()
            Thread.sleep(pcm.size * 1000L / RATE + 50)
        } finally {
            track.release()
        }
    }
}
