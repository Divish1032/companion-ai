package ai.companion.companion_mobile

import android.content.Context
import android.media.AudioManager
import android.os.Build
import android.os.SystemClock
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val methods = "ai.companion.companion_mobile/playback_telemetry/methods"
    private val events = "ai.companion.companion_mobile/playback_telemetry/events"
    private var sink: EventChannel.EventSink? = null
    private var pendingTurnId: String? = null
    private var callbackRegistered = false

    private val playbackCallback = object : AudioManager.AudioPlaybackCallback() {
        override fun onPlaybackConfigChanged(configs: MutableList<android.media.AudioPlaybackConfiguration>) {
            val turnId = pendingTurnId ?: return
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
            // Android deliberately does not expose the client UID or active
            // state on this public API. The immediately preceding reliable
            // server marker narrows this to the app's expected TTS window;
            // telemetry labels the result as an output-configuration proxy.
            if (configs.isNotEmpty()) {
                pendingTurnId = null
                runOnUiThread {
                    sink?.success(
                        mapOf(
                            "turn_id" to turnId,
                            "playback_timestamp_ms" to SystemClock.elapsedRealtime(),
                            "source" to "android_audio_playback_configuration_proxy"
                        )
                    )
                }
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, events).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, eventSink: EventChannel.EventSink?) {
                    sink = eventSink
                }

                override fun onCancel(arguments: Any?) {
                    sink = null
                }
            }
        )
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methods).setMethodCallHandler { call, result ->
            if (call.method != "arm") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val turnId = call.argument<String>("turn_id")
            if (turnId.isNullOrBlank() || Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
                result.success(mapOf("status" to "unsupported"))
                return@setMethodCallHandler
            }
            pendingTurnId = turnId
            if (!callbackRegistered) {
                (getSystemService(Context.AUDIO_SERVICE) as AudioManager)
                    .registerAudioPlaybackCallback(playbackCallback, null)
                callbackRegistered = true
            }
            result.success(mapOf("status" to "armed"))
        }
    }

    override fun onDestroy() {
        if (callbackRegistered && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            (getSystemService(Context.AUDIO_SERVICE) as AudioManager)
                .unregisterAudioPlaybackCallback(playbackCallback)
        }
        callbackRegistered = false
        pendingTurnId = null
        super.onDestroy()
    }
}
