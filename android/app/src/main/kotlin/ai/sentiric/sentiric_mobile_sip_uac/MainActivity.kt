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
    private lateinit var audioManager: AudioManager

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        
        // [KRİTİK FIX - SES KISIKLIĞI ÇÖZÜMÜ]: 
        // Cihazın yan tarafındaki fiziksel ses tuşlarının Müzik değil, 
        // "Arama Sesi"ni (Voice Call) kontrol etmesini zorunlu kılarız.
        volumeControlStream = AudioManager.STREAM_VOICE_CALL

        try {
            System.loadLibrary("mobile_uac")
            android.util.Log.i("SentiricMobile", "Rust Native Library Loaded Successfully")
        } catch (e: UnsatisfiedLinkError) {
            android.util.Log.e("SentiricMobile", "Failed to load Rust Native Library", e)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setInCallMode" -> {
                    val speakerOn = call.argument<Boolean>("speakerOn") ?: false
                    
                    // İşletim sistemine VoIP modunda olduğumuzu bildir (Donanım Yankı Engelleyiciyi açar)
                    audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
                    audioManager.isSpeakerphoneOn = speakerOn
                    
                    // Android'den ses odağını zorla al (Arka planda çalan müziği vs susturur)
                    audioManager.requestAudioFocus(null, AudioManager.STREAM_VOICE_CALL, AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                    
                    result.success(null)
                }
                "setNormalMode" -> {
                    // Çağrı bittiğinde telefonu normal haline döndür
                    audioManager.mode = AudioManager.MODE_NORMAL
                    audioManager.isSpeakerphoneOn = false
                    audioManager.abandonAudioFocus(null)
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}