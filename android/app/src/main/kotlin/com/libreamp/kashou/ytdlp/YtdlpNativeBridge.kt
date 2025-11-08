package com.libreamp.kashou.ytdlp

import android.content.Context
import com.google.gson.Gson
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File

// standalone yt-dlp binary, no python needed
class YtdlpNativeBridge(private val context: Context) {
    private val gson = Gson()
    private val ytdlpBinary: String
    
    init {
        ytdlpBinary = extractYtdlpBinary()
    }
    
    private fun extractYtdlpBinary(): String {
        val binDir = File(context.filesDir, "bin")
        binDir.mkdirs()
        
        val ytdlp = File(binDir, "yt-dlp")
        if (!ytdlp.exists()) {
            // Copy yt-dlp binary from assets
            context.assets.open("bin/yt-dlp").use { input ->
                ytdlp.outputStream().use { output ->
                    input.copyTo(output)
                }
            }
            ytdlp.setExecutable(true)
        }
        
        return ytdlp.absolutePath
    }
    
    suspend fun searchYouTube(query: String, limit: Int = 10): String = withContext(Dispatchers.IO) {
        try {
            val command = listOf(
                ytdlpBinary,
                "--dump-json",
                "--flat-playlist",
                "--skip-download",
                "--no-warnings",
                "--geo-bypass",
                "--extractor-args", "youtube:player_client=android,web;player_skip=js,configs",
                "ytsearch$limit:$query"
            )
            
            val output = executeCommand(command)
            
            // Parse yt-dlp JSON output
            val results = output.trim().split("\n")
                .filter { it.isNotBlank() }
                .mapNotNull { line ->
                    try {
                        gson.fromJson(line, Map::class.java)
                    } catch (e: Exception) {
                        null
                    }
                }
                .map { video ->
                    mapOf(
                        "id" to video["id"],
                        "title" to video["title"],
                        "url" to "https://www.youtube.com/watch?v=${video["id"]}",
                        "channel" to video["uploader"],
                        "duration" to video["duration"],
                        "views" to video["view_count"],
                        "thumbnail" to "https://i.ytimg.com/vi/${video["id"]}/hqdefault.jpg"
                    )
                }
            
            val response = mapOf(
                "query" to query,
                "limit" to limit,
                "results" to results
            )
            
            gson.toJson(response)
        } catch (e: Exception) {
            android.util.Log.e("YtdlpNativeBridge", "Search error: ${e.message}", e)
            gson.toJson(mapOf("error" to e.message))
        }
    }
    
    suspend fun getAudioUrl(videoUrl: String): String = withContext(Dispatchers.IO) {
        try {
            android.util.Log.d("YtdlpNativeBridge", "Fetching audio URL for: $videoUrl")
            
            val command = listOf(
                ytdlpBinary,
                "--dump-json",
                "--skip-download",
                "--no-warnings",
                "--format", "bestaudio/best",
                "--geo-bypass",
                "--extractor-args", "youtube:player_client=android,web;player_skip=js,configs",
                videoUrl
            )
            
            val output = executeCommand(command)
            val info = gson.fromJson(output, Map::class.java) as Map<*, *>
            
            // Extract best audio format
            val formats = info["formats"] as? List<*>
            val audioFormat = formats?.firstOrNull { format ->
                val fmt = format as? Map<*, *>
                val mimeType = fmt?.get("mime_type") as? String ?: ""
                mimeType.startsWith("audio/")
            } as? Map<*, *>
            
            val audioUrl = audioFormat?.get("url") as? String
                ?: info["url"] as? String
                ?: throw Exception("No audio URL found")
            
            val result = mapOf(
                "id" to info["id"],
                "title" to info["title"],
                "channel" to info["uploader"],
                "channel_url" to info["channel_url"],
                "thumbnail" to info["thumbnail"],
                "duration" to info["duration"],
                "views" to info["view_count"],
                "audio" to mapOf(
                    "download_url" to audioUrl,
                    "ext" to (audioFormat?.get("ext") ?: info["ext"]),
                    "abr" to (audioFormat?.get("abr") ?: info["abr"]),
                    "codec" to (audioFormat?.get("acodec") ?: info["acodec"])
                ),
                "source_url" to videoUrl
            )
            
            android.util.Log.d("YtdlpNativeBridge", "Got audio URL: ${audioUrl.take(100)}")
            gson.toJson(result)
        } catch (e: Exception) {
            android.util.Log.e("YtdlpNativeBridge", "Audio URL error: ${e.message}", e)
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
            throw Exception("yt-dlp exited with code $exitCode: ${output.take(500)}")
        }
        
        return output
    }
}
