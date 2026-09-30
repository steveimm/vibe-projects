package id.steveimm.pocketpilot.ui.capsule.voice

import android.content.Context
import android.speech.SpeechRecognizer
import com.google.common.truth.Truth.assertThat
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkStatic
import io.mockk.unmockkStatic
import io.mockk.verify
import org.junit.Test

class AndroidRecognizerFactoryTest {
    @Test
    fun `remote recognition availability does not enable dictation`() {
        mockkStatic(SpeechRecognizer::class)
        try {
            val context = mockk<Context>()
            every { SpeechRecognizer.isRecognitionAvailable(context) } returns true
            every { SpeechRecognizer.isOnDeviceRecognitionAvailable(context) } returns false
            val factory = AndroidRecognizerFactory(context)
            assertThat(factory.isAvailable()).isFalse()
            assertThat(factory.create()).isNull()
            verify(exactly = 0) { SpeechRecognizer.createSpeechRecognizer(any()) }
        } finally { unmockkStatic(SpeechRecognizer::class) }
    }

    @Test
    fun `available dictation uses the on-device recognizer without a remote fallback`() {
        mockkStatic(SpeechRecognizer::class)
        try {
            val context = mockk<Context>()
            val recognizer = mockk<SpeechRecognizer>(relaxed = true)
            every { SpeechRecognizer.isOnDeviceRecognitionAvailable(context) } returns true
            every { SpeechRecognizer.createOnDeviceSpeechRecognizer(context) } returns recognizer
            val instance = AndroidRecognizerFactory(context).create()
            assertThat(instance).isNotNull()
            instance!!.destroy()
            verify(exactly = 1) { SpeechRecognizer.createOnDeviceSpeechRecognizer(context) }
            verify(exactly = 1) { recognizer.destroy() }
            verify(exactly = 0) { SpeechRecognizer.createSpeechRecognizer(any()) }
        } finally { unmockkStatic(SpeechRecognizer::class) }
    }
}
