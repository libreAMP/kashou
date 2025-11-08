#!/usr/bin/env python3
"""
Native yt-dlp runner for Android JNI
Your exact backend logic running client-side
"""
import sys
import json
import time
import yt_dlp

# Simple in-memory caches (no TTLCache needed for mobile)
search_cache = {}
download_cache = {}

def select_preferred_audio_format(info):
    """Select best direct audio format, avoiding manifests"""
    def iter_formats():
        requested = info.get("requested_formats") or []
        for fmt in requested:
            yield fmt
        for fmt in info.get("formats") or []:
            yield fmt

    direct_candidates = []
    fallback_candidates = []

    for fmt in iter_formats():
        if not isinstance(fmt, dict):
            continue
        if fmt.get("acodec") in (None, "none"):
            continue

        url = fmt.get("url") or ""
        protocol = fmt.get("protocol") or ""
        is_manifest = protocol in {"m3u8", "m3u8_native", "http_dash_segments"} or ".m3u8" in url

        target_list = fallback_candidates if is_manifest else direct_candidates
        target_list.append(fmt)

    sorter = lambda f: (f.get("abr") or 0, f.get("tbr") or 0)
    direct_candidates.sort(key=sorter, reverse=True)
    fallback_candidates.sort(key=sorter, reverse=True)

    if direct_candidates:
        return direct_candidates[0]
    if fallback_candidates:
        return fallback_candidates[0]

    url = info.get("url")
    if not url:
        return None

    return {
        "url": url,
        "ext": info.get("ext"),
        "abr": info.get("abr"),
        "asr": info.get("asr"),
        "filesize_approx": info.get("filesize_approx"),
        "codec": info.get("acodec"),
        "format_id": info.get("format_id"),
        "protocol": info.get("protocol"),
        "mime_type": info.get("mime_type"),
    }

def search_youtube(query, limit=5):
    """Search YouTube videos"""
    cache_key = f"{query}_{limit}"
    if cache_key in search_cache:
        result = search_cache[cache_key].copy()
        result["cached"] = True
        return result

    ydl_opts = {
        "quiet": True,
        "no_warnings": True,
        "skip_download": True,
        "extract_flat": True,
        "no_check_certificate": True,
        "no_color": True,
        "geo_bypass": True,
        "socket_timeout": 15,
        "extractor_retries": 3,
        "fragment_retries": 3,
        "extractor_args": {
            "youtube": {
                "player_client": ["android", "web"],
                "player_skip": ["js", "configs"],
                "max_comments": [0],
            }
        },
        "http_headers": {
            "User-Agent": "Mozilla/5.0 (Linux; Android 11) AppleWebKit/537.36",
        },
    }

    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            data = ydl.extract_info(f"ytsearch{limit}:{query}", download=False)

        results = data.get("entries", [])

        result = {
            "query": query,
            "limit": limit,
            "timestamp": int(time.time()),
            "results": [
                {
                    "id": v.get("id"),
                    "title": v.get("title"),
                    "url": f"https://www.youtube.com/watch?v={v.get('id')}",
                    "channel": v.get("uploader"),
                    "duration": v.get("duration"),
                    "views": v.get("view_count"),
                    "upload_date": v.get("upload_date"),
                    "thumbnail": f"https://i.ytimg.com/vi/{v.get('id')}/hqdefault.jpg",
                }
                for v in results if v.get("id")
            ],
        }

        search_cache[cache_key] = result.copy()
        result["cached"] = False
        return result
    except Exception as e:
        return {"error": str(e)}

def get_audio_url(video_url):
    """Extract best audio stream URL"""
    cache_key = video_url
    if cache_key in download_cache:
        result = download_cache[cache_key].copy()
        result["cached"] = True
        return result

    ydl_opts = {
        "quiet": True,
        "no_warnings": True,
        "skip_download": True,
        "format": "bestaudio/best[abr<=128]/worst",
        "nocheckcertificate": True,
        "no_color": True,
        "geo_bypass": True,
        "socket_timeout": 15,
        "extractor_retries": 3,
        "fragment_retries": 3,
        "extractor_args": {
            "youtube": {
                "player_client": ["android", "web"],
                "player_skip": ["js", "configs"],
                "max_comments": [0],
            }
        },
        "http_headers": {
            "User-Agent": "Mozilla/5.0 (Linux; Android 11) AppleWebKit/537.36",
        },
    }

    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(video_url, download=False)
    except Exception as e:
        # Fallback
        ydl_opts_fallback = {
            "quiet": True,
            "no_warnings": True,
            "skip_download": True,
            "format": "worst",
            "nocheckcertificate": True,
            "socket_timeout": 10,
        }
        try:
            with yt_dlp.YoutubeDL(ydl_opts_fallback) as ydl:
                info = ydl.extract_info(video_url, download=False)
        except Exception as e2:
            return {"error": f"Extraction failed: {str(e2)}"}

    if not info:
        return {"error": "Could not extract info"}

    selected_format = select_preferred_audio_format(info)

    if not selected_format or not selected_format.get("url"):
        return {"error": "Could not extract audio URL"}

    best_audio_url = selected_format["url"]

    result = {
        "id": info.get("id"),
        "title": info.get("title"),
        "channel": info.get("uploader"),
        "channel_url": info.get("channel_url"),
        "thumbnail": info.get("thumbnail"),
        "duration": info.get("duration"),
        "views": info.get("view_count"),
        "upload_date": info.get("upload_date"),
        "categories": info.get("categories"),
        "tags": info.get("tags"),
        "description": info.get("description"),
        "audio": {
            "download_url": best_audio_url,
            "ext": selected_format.get("ext") or info.get("ext"),
            "abr": selected_format.get("abr") or info.get("abr"),
            "asr": selected_format.get("asr") or info.get("asr"),
            "filesize": selected_format.get("filesize"),
            "filesize_approx": selected_format.get("filesize_approx") or info.get("filesize_approx"),
            "codec": selected_format.get("acodec") or info.get("acodec"),
            "format_id": selected_format.get("format_id"),
            "protocol": selected_format.get("protocol"),
            "mime_type": selected_format.get("mime_type"),
        },
        "source_url": video_url,
    }

    download_cache[cache_key] = result
    response = result.copy()
    response["cached"] = False
    return response

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(json.dumps({"error": "No command specified"}))
        sys.exit(1)
    
    command = sys.argv[1]
    
    try:
        if command == "search":
            query = sys.argv[2] if len(sys.argv) > 2 else ""
            limit = int(sys.argv[3]) if len(sys.argv) > 3 else 5
            result = search_youtube(query, limit)
            print(json.dumps(result))
        
        elif command == "download":
            url = sys.argv[2] if len(sys.argv) > 2 else ""
            result = get_audio_url(url)
            print(json.dumps(result))
        
        else:
            print(json.dumps({"error": f"Unknown command: {command}"}))
            sys.exit(1)
    
    except Exception as e:
        print(json.dumps({"error": str(e)}))
        sys.exit(1)
