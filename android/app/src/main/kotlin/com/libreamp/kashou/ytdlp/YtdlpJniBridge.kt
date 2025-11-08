package com.libreamp.kashou.ytdlp

import android.content.Context
import com.google.gson.Gson
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File

// runs bundled yt-dlp through an extracted python binary
class YtdlpJniBridge(private val context: Context) {
    private val gson = Gson()
    private val pythonExecutable: String
    private val scriptPath: String
    
    init {
        // Extract Python executable and script from assets
        pythonExecutable = extractPythonExecutable()
        scriptPath = extractYtdlpScript()
    }
    
    private fun extractPythonExecutable(): String {
        val pythonDir = File(context.filesDir, "python")
        pythonDir.mkdirs()
        
        val pythonBin = File(pythonDir, "python3")
        if (!pythonBin.exists()) {
            // Copy python3 binary from assets
            context.assets.open("python/python3").use { input ->
                pythonBin.outputStream().use { output ->
                    input.copyTo(output)
                }
            }
            pythonBin.setExecutable(true)
        }
        
        return pythonBin.absolutePath
    }
    
    private fun extractYtdlpScript(): String {
        val scriptFile = File(context.filesDir, "ytdlp_native.py")
        if (!scriptFile.exists()) {
            // Copy Python script from assets
            context.assets.open("python/ytdlp_native.py").use { input ->
                scriptFile.outputStream().use { output ->
                    input.copyTo(output)
                }
            }
        }
        return scriptFile.absolutePath
    }
    
    suspend fun searchYouTube(query: String, limit: Int = 10): String = withContext(Dispatchers.IO) {
        try {
            val command = listOf(
                pythonExecutable,
                scriptPath,
                "search",
                query,
                limit.toString()
            )
            
            val result = executeCommand(command)
            android.util.Log.d("YtdlpJniBridge", "Search result: ${result.take(200)}")
            result
        } catch (e: Exception) {
            android.util.Log.e("YtdlpJniBridge", "Search error: ${e.message}", e)
            gson.toJson(mapOf("error" to e.message))
        }
    }
    
    suspend fun getAudioUrl(videoUrl: String): String = withContext(Dispatchers.IO) {
        try {
            android.util.Log.d("YtdlpJniBridge", "Fetching audio URL for: $videoUrl")
            
            val command = listOf(
                pythonExecutable,
                scriptPath,
                "download",
                videoUrl
            )
            
            val result = executeCommand(command)
            
            // Parse to check for errors
            val resultMap = gson.fromJson(result, Map::class.java)
            if (resultMap?.containsKey("error") == true) {
                android.util.Log.e("YtdlpJniBridge", "yt-dlp error: ${resultMap["error"]}")
            } else {
                val audioUrl = (resultMap?.get("audio") as? Map<*, *>)?.get("download_url")
                android.util.Log.d("YtdlpJniBridge", "Got audio URL: ${audioUrl?.toString()?.take(100)}")
            }
            
            result
        } catch (e: Exception) {
            android.util.Log.e("YtdlpJniBridge", "Audio URL error: ${e.message}", e)
            gson.toJson(mapOf("error" to e.message))
        }
    }
    
    private fun executeCommand(command: List<String>): String {
        val process = ProcessBuilder(command)
            .redirectErrorStream(true)
            .start()
        
        val output = process.inputStream.bufferedReader().readText()
        val exitCode = process.waitFor()
        
        if (exitCode != 0) {
            throw Exception("Process exited with code $exitCode: $output")
        }
        
        return output
    }
}
