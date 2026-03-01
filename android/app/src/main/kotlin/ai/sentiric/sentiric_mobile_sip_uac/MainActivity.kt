// sentiric-sip-mobile-uac/android/app/src/main/kotlin/ai/sentiric/sentiric_mobile_sip_uac/MainActivity.kt
package ai.sentiric.sentiric_mobile_sip_uac

import android.content.Context
import android.media.AudioManager
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "ai.sentiric.mobile/audio_route"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Rust kütüphanesini JVM'ye yüklüyoruz
        try {
            System.loadLibrary("mobile_uac")
            android.util.Log.i("SentiricMobile", "Rust Native Library Loaded Successfully")
        } catch (e: UnsatisfiedLinkError) {
            android.util.Log.e("SentiricMobile", "Failed to load Rust Native Library", e)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Flutter'dan gelen Ses Yönlendirme (Speaker/Earpiece) komutlarını dinler
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager

            when (call.method) {
                "setInCallMode" -> {
                    val speakerOn = call.argument<Boolean>("speakerOn") ?: false
                    // [KRİTİK]: Android'e "Bu bir telefon görüşmesidir" der. Donanımsal Yankı Engelleyici (AEC) devreye girer.
                    audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
                    audioManager.isSpeakerphoneOn = speakerOn
                    result.success(null)
                }
                "setNormalMode" -> {
                    // Çağrı bitince telefonu normal müzik/medya moduna geri döndür
                    audioManager.mode = AudioManager.MODE_NORMAL
                    audioManager.isSpeakerphoneOn = false
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}