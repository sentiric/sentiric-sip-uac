package ai.sentiric.sentiric_sip_uac

import android.content.Context
import android.media.AudioManager
import android.os.Bundle
import android.os.PowerManager // [UX FIX] WakeLock
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "ai.sentiric.sentiric_sip_uac/audio_route"
    private lateinit var audioManager: AudioManager
    private var previousMusicVolume: Int = 0
    private var previousMode: Int = AudioManager.MODE_NORMAL
    
    // [UX FIX] Cihaz arka plandayken CPU'nun uyumasını engeller.
    private var wakeLock: PowerManager.WakeLock? = null
    
    // [UX FIX] Yakınlık sensörü: Telefon kulağa geldiğinde ekranı karartır.
    private var proximityWakeLock: PowerManager.WakeLock? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        volumeControlStream = AudioManager.STREAM_VOICE_CALL

        try {
            System.loadLibrary("uac")
        } catch (e: UnsatisfiedLinkError) {
            android.util.Log.e("UAC", "Failed to load Rust Native Library", e)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setInCallMode" -> {
                    previousMusicVolume = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
                    previousMode = audioManager.mode
                    
                    val maxMusicVol = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                    val targetVol = (maxMusicVol * 0.8).toInt() 
                    audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, targetVol, 0)

                    audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
                    audioManager.isSpeakerphoneOn = false
                    audioManager.requestAudioFocus(null, AudioManager.STREAM_VOICE_CALL, AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_EXCLUSIVE)
                    
                    val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
                    
                    // [UX FIX] Arka planda kesintisiz çağrı için WakeLock alınıyor.
                    if (wakeLock == null) {
                        wakeLock = powerManager.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "SentiricUAC::CallWakeLock")
                    }
                    wakeLock?.takeIf { !it.isHeld }?.acquire()

                    // [UX FIX] Yakınlık sensörü kilitleniyor (Ekran karartma).
                    if (proximityWakeLock == null) {
                        if (powerManager.isWakeLockLevelSupported(PowerManager.PROXIMITY_SCREEN_OFF_WAKE_LOCK)) {
                            proximityWakeLock = powerManager.newWakeLock(PowerManager.PROXIMITY_SCREEN_OFF_WAKE_LOCK, "SentiricUAC::ProximityWakeLock")
                        }
                    }
                    proximityWakeLock?.takeIf { !it.isHeld }?.acquire()

                    result.success(null)
                }
                "toggleSpeaker" -> {
                    val speakerOn = call.argument<Boolean>("speakerOn") ?: false
                    audioManager.isSpeakerphoneOn = speakerOn
                    
                    // [UX FIX] Hoparlör modunda yakınlık sensörü devre dışı bırakılır ki ekranı görebilelim.
                    if (speakerOn) {
                        proximityWakeLock?.takeIf { it.isHeld }?.release()
                    } else {
                        proximityWakeLock?.takeIf { !it.isHeld }?.acquire()
                    }
                    
                    result.success(null)
                }
                "setNormalMode" -> {
                    audioManager.mode = previousMode
                    audioManager.isSpeakerphoneOn = false
                    audioManager.abandonAudioFocus(null)
                    audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, previousMusicVolume, 0)
                    
                    // [UX FIX] Çağrı bittiğinde WakeLock ve Proximity kilitleri serbest bırakılır.
                    wakeLock?.takeIf { it.isHeld }?.release()
                    proximityWakeLock?.takeIf { it.isHeld }?.release()
                    
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}