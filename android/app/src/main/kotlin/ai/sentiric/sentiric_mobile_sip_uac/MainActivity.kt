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
    private var previousMusicVolume: Int = 0
    private var previousMode: Int = AudioManager.MODE_NORMAL

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
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
                    // MİMARİNİN GEREĞİ: Bu fonksiyon çağrı başlamadan önce 1 KERE çağrılır.
                    previousMusicVolume = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
                    previousMode = audioManager.mode
                    
                    val maxMusicVol = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                    val targetVol = (maxMusicVol * 0.8).toInt() 
                    audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, targetVol, 0)

                    // Modu iletişime al ve odak iste. (AAudio/cpal stream başlamadan hemen önce olmalı)
                    audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
                    audioManager.isSpeakerphoneOn = false
                    audioManager.requestAudioFocus(null, AudioManager.STREAM_VOICE_CALL, AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_EXCLUSIVE)
                    
                    result.success(null)
                }
                "toggleSpeaker" -> {
                    // MİMARİNİN GEREĞİ: Çağrı ortasında AAudio stream'i öldürmemek için SADECE hoparlör rotası değişir.
                    val speakerOn = call.argument<Boolean>("speakerOn") ?: false
                    audioManager.isSpeakerphoneOn = speakerOn
                    result.success(null)
                }
                "setNormalMode" -> {
                    // Çağrı bittiğinde eski duruma dön.
                    audioManager.mode = previousMode
                    audioManager.isSpeakerphoneOn = false
                    audioManager.abandonAudioFocus(null)
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