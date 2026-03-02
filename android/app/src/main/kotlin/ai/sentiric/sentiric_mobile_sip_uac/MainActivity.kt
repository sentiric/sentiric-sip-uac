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
    
    // Eski ses seviyesini saklamak için
    private var previousMusicVolume: Int = 0

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        
        // Varsayılan olarak ses tuşları Arama Sesini kontrol etsin
        volumeControlStream = AudioManager.STREAM_VOICE_CALL

        try {
            System.loadLibrary("mobile_uac")
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
                    
                    // 1. Önceki Müzik Sesini Kaydet
                    previousMusicVolume = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
                    
                    // 2. Müzik Sesini (RTP akışımız buradan geliyor) Max'a yakın bir seviyeye çek
                    //    Arama modunda olduğumuz için bu kulağı sağır etmez, sadece duyulabilir yapar.
                    val maxMusicVol = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                    // %80 seviyesi güvenlidir
                    val targetVol = (maxMusicVol * 0.8).toInt() 
                    audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, targetVol, 0)

                    // 3. Modu Değiştir (AEC ve Routing için kritik)
                    audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
                    
                    if (speakerOn) {
                        audioManager.isSpeakerphoneOn = true
                    } else {
                        audioManager.isSpeakerphoneOn = false
                    }
                    
                    // 4. Ses Odağını Al
                    audioManager.requestAudioFocus(null, AudioManager.STREAM_VOICE_CALL, AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_EXCLUSIVE)
                    
                    result.success(null)
                }
                "setNormalMode" -> {
                    // Modu Normale Döndür
                    audioManager.mode = AudioManager.MODE_NORMAL
                    audioManager.isSpeakerphoneOn = false
                    audioManager.abandonAudioFocus(null)
                    
                    // Ses Seviyesini Eski Haline Getir (Kullanıcıya saygı)
                    audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, previousMusicVolume, 0)
                    
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}