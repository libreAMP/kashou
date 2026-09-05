package com.libreamp.kashou

import android.media.audiofx.Equalizer
import android.media.audiofx.BassBoost
import android.media.audiofx.Virtualizer
import android.os.Bundle
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    private val EQUALIZER_CHANNEL = "com.libreamp.kashou/equalizer"
    private val INTENT_CHANNEL = "com.libreamp.kashou/intent"
    private var equalizer: Equalizer? = null
    private var bassBoost: BassBoost? = null
    private var virtualizer: Virtualizer? = null
    private var pendingLink: String? = null
    private var intentChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        pendingLink = intent?.data?.toString()
    }

    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        intent.data?.toString()?.let {
            pendingLink = it
            intentChannel?.invokeMethod("link", it)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        intentChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, INTENT_CHANNEL)
        intentChannel?.setMethodCallHandler { call, result ->
            if (call.method == "consumeLink") {
                result.success(pendingLink)
                pendingLink = null
            } else {
                result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, EQUALIZER_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "initEqualizer" -> {
                    val sessionId = call.argument<Int>("sessionId")
                    if (sessionId != null) {
                        initEqualizer(sessionId)
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGUMENT", "Session ID is required", null)
                    }
                }
                "setBandLevel" -> {
                    val bandId = call.argument<Int>("bandId")
                    val level = call.argument<Int>("level")
                    if (bandId != null && level != null) {
                        setBandLevel(bandId, level)
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGUMENT", "Band ID and level are required", null)
                    }
                }
                "getBandLevelRange" -> {
                    val range = getBandLevelRange()
                    result.success(range)
                }
                "getCenterBandFreqs" -> {
                    val freqs = getCenterBandFreqs()
                    result.success(freqs)
                }
                "getPresetNames" -> {
                    val presets = getPresetNames()
                    result.success(presets)
                }
                "setPreset" -> {
                    val presetName = call.argument<String>("presetName")
                    if (presetName != null) {
                        setPreset(presetName)
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGUMENT", "Preset name is required", null)
                    }
                }
                "getPresetBandLevels" -> {
                    val levels = getPresetBandLevels()
                    result.success(levels)
                }
                "releaseEqualizer" -> {
                    releaseEqualizer()
                    result.success(null)
                }
                "isAllFilesAccess" -> {
                    result.success(android.os.Environment.isExternalStorageManager())
                }
                "openAllFilesSettings" -> {
                    val intent = android.content.Intent(
                        android.provider.Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
                        android.net.Uri.parse("package:$packageName")
                    )
                    startActivity(intent)
                    result.success(null)
                }
                "setBassBoost" -> {
                    val strength = call.argument<Int>("strength")
                    if (strength != null) {
                        setBassBoost(strength)
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGUMENT", "Strength is required", null)
                    }
                }
                "setVirtualizer" -> {
                    val strength = call.argument<Int>("strength")
                    if (strength != null) {
                        setVirtualizer(strength)
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGUMENT", "Strength is required", null)
                    }
                }
                "enableEffects" -> {
                    val enabled = call.argument<Boolean>("enabled")
                    if (enabled != null) {
                        enableEffects(enabled)
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGUMENT", "Enabled flag is required", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
            }

    // created idle, enabling these here cost loudness
    private fun initEqualizer(sessionId: Int) {
        equalizer = Equalizer(0, sessionId)
        bassBoost = BassBoost(0, sessionId)
        virtualizer = Virtualizer(0, sessionId)
    }

    private fun setBandLevel(bandId: Int, level: Int) {
        equalizer?.setBandLevel(bandId.toShort(), level.toShort())
    }

    private fun getBandLevelRange(): List<Int> {
        return equalizer?.let {
            listOf(it.bandLevelRange[0].toInt(), it.bandLevelRange[1].toInt())
        } ?: listOf(-1500, 1500) // Default range in millibels
    }

    private fun getCenterBandFreqs(): List<Int> {
        return equalizer?.let { eq ->
            (0 until eq.numberOfBands).map { eq.getCenterFreq(it.toShort()).toInt() }
        } ?: emptyList()
    }

    private fun getPresetNames(): List<String> {
        return equalizer?.let { eq ->
            (0 until eq.numberOfPresets).map { eq.getPresetName(it.toShort()) }
        } ?: emptyList()
    }

    private fun setPreset(presetName: String) {
        equalizer?.let { eq ->
            for (i in 0 until eq.numberOfPresets) {
                if (eq.getPresetName(i.toShort()) == presetName) {
                    eq.usePreset(i.toShort())
                    break
                }
            }
        }
    }

    private fun getPresetBandLevels(): List<Double> {
        return equalizer?.let { eq ->
            (0 until eq.numberOfBands).map { eq.getBandLevel(it.toShort()).toDouble() }
        } ?: emptyList()
    }

    private fun setBassBoost(strength: Int) {
        bassBoost?.setStrength(strength.toShort())
    }

    private fun setVirtualizer(strength: Int) {
        virtualizer?.setStrength(strength.toShort())
    }

    private fun enableEffects(enabled: Boolean) {
        equalizer?.enabled = enabled
        bassBoost?.enabled = enabled
        virtualizer?.enabled = enabled
    }

    private fun releaseEqualizer() {
        equalizer?.release()
        equalizer = null
        bassBoost?.release()
        bassBoost = null
        virtualizer?.release()
        virtualizer = null
    }

    override fun onDestroy() {
        super.onDestroy()
        releaseEqualizer()
    }
}
