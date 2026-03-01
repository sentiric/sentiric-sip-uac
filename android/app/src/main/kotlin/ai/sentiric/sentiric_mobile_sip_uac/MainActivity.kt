// sentiric-sip-mobile-uac/android/app/src/main/kotlin/ai/sentiric/sentiric_mobile_sip_uac/MainActivity.kt
package ai.sentiric.sentiric_mobile_sip_uac

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity() {
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // [KRİTİK FIX]: Rust kütüphanesini uygulama başlarken JVM'ye yüklüyoruz.
        // Bu işlem, rust tarafındaki JNI_OnLoad fonksiyonunu tetikleyecek ve 
        // Oboe/CPAL için gerekli olan Android Context'ini sağlayacaktır.
        try {
            System.loadLibrary("mobile_uac")
            android.util.Log.i("SentiricMobile", "Rust Native Library Loaded Successfully")
        } catch (e: UnsatisfiedLinkError) {
            android.util.Log.e("SentiricMobile", "Failed to load Rust Native Library", e)
        }
    }
}