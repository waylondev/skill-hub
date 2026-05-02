---
name: tool-dl-media
description: >
  Use this skill when the user wants to download videos or audio from any online
  platform (supports 1000+ sites via yt-dlp). Supports quality selection, subtitle/caption
  extraction, audio-only download, and format conversion. When user only provides
  keywords (e.g., "a song called X"), proactively search for the URL first.
metadata:
  version: 1.1.0
  displayName: Download Media from Online Platforms
  domain: tool
  action: dl
  object: media
  tags: [download, media, video, audio, yt-dlp, subtitle, playlist, bilibili, uv]
  type: SKILL
inputs:
  - name: url
    type: string
    required: false
    description: Media URL to download (video, audio, playlist, etc.). If not provided, AI should search for the URL first.
  - name: query
    type: string
    required: false
    description: Search keywords to find the media URL (e.g., song name, video title). Used when url is not provided.
  - name: quality
    type: string
    required: false
    description: >
      Desired quality: best, 4k, 1080p, 720p, 480p, 360p, audio-only.
      Default: best available
  - name: output_format
    type: string
    required: false
    description: Output format (mp4, mkv, webm, mp3, m4a). Default: mp4 for video, original for audio
  - name: output_dir
    type: string
    required: false
    description: Output directory path. Default: ~/Downloads
  - name: subtitles
    type: boolean
    required: false
    description: Download subtitles/captions if available. Default: false
  - name: subtitle_lang
    type: string
    required: false
    description: Subtitle language code (en, zh, ja, etc.). Default: first available
  - name: use_cookies
    type: boolean
    required: false
    description: >
      Use browser cookies for authenticated access (high quality, age-restricted, premium content).
      Default: false
---

# Download Media from Online Platforms

## Purpose

Download videos and audio from any supported online platform (1000+ sites via yt-dlp). Supports quality selection, subtitle/caption extraction, audio-only download, and format conversion.

## Trigger Conditions

Use this Skill when:
- User provides a media URL and wants to download it
- User provides keywords (song name, video title) and wants to find and download it
- User wants to extract audio from a video (podcast, music, etc.)
- User needs to download subtitles/captions along with media
- User wants to archive media content for offline access
- User needs specific quality or format requirements

## Prerequisites

- `yt-dlp` is installed and available in PATH (or via `uv tool run yt-dlp`)
- `ffmpeg` is installed (required for merging separate video+audio streams and format conversion)
- Internet connection is available
- Target platform is accessible from the network

### Prerequisite Installation Guide

Before proceeding, check if prerequisites are installed. If any are missing:

1. **Check**: Verify if yt-dlp and ffmpeg are available using multiple methods:
   ```bash
   # Direct check
   yt-dlp --version
   ffmpeg -version
   
   # Via uv tool (if installed via uv)
   uv tool list | grep yt-dlp
   ```
2. **If missing**: Inform user which tools are missing and provide installation instructions
3. **Guide**: Offer to provide platform-specific installation commands from `references/installation-guide.md`
4. **Verify**: After user confirms installation, re-check that tools are accessible
5. **Proceed**: Continue with download only when all prerequisites are satisfied

See `references/installation-guide.md` for detailed installation instructions, troubleshooting, and platform-specific commands.

## Execution Steps

### Step 1: Validate Input Parameters

Before executing:
- If `url` is provided, validate URL format (should start with http:// or https://)
- If `url` is not provided but `query` is provided, proceed to Step 1.5 (URL Discovery)
- If neither `url` nor `query` is provided, ask user to provide at least one
- If `quality` is provided, ensure it's a valid option (best, 4k, 1080p, 720p, 480p, 360p, audio-only)
- If `output_format` is provided, ensure it's supported (mp4, mkv, webm, mp3, m4a)
- If validation fails, inform user with specific error message

### Step 1.5: URL Discovery (When url is not provided)

When user only provides keywords (e.g., "download the song 洗牌", "a video about X"):

1. **Web Search**: Use web search to find relevant media URLs
   - Prioritize major platforms: YouTube, Bilibili, etc.
   - Search query format: `site:bilibili.com {keywords}` or `site:youtube.com {keywords}`
   - **Note**: Do NOT use yt-dlp's built-in search (`ytsearch:`) as it may timeout. Use web search instead.
   
2. **Present Options to User**: Show search results using the standardized template below:

   **Batch Results Display Template**:
   ```
   I found these results for "{query}":
   
   No. | Platform | Title | Duration | URL
   ----|----------|-------|----------|----
   1   | Bilibili | {title} | {duration} | {url}
   2   | YouTube  | {title} | {duration} | {url}
   3   | Bilibili | {title} | {duration} | {url}
   
   Please reply with the number (1-3) or provide a specific URL.
   ```

3. **User Selection**: Wait for user to confirm which URL to download

4. **Fallback**: If no results found, inform user and ask them to provide a URL manually

### Step 2: Assess Usage Context and Compliance

Before downloading, assess the usage context:
- Determine if the download is for **personal/educational use**, **research**, or **commercial purposes**
- If commercial use is indicated, inform user about copyright considerations
- If content appears to be copyrighted material (e.g., movies, music videos, premium content):
  - Inform user about potential copyright restrictions
  - Ask user to confirm they have permission or intend personal/educational use
- **Proceed only after user confirmation** or if usage context is clearly personal/educational

### Step 3: Detect Platform and Quality Requirements

Based on the URL, auto-detect the platform and quality access requirements:

**Platform Detection**:
- yt-dlp supports 1000+ platforms and auto-detects the appropriate extractor
- For known platforms, apply platform-specific quality guidance

**Platform-Specific Notes**:
- **Bilibili (B站)**: Supports BV号和AV号链接 (e.g., `https://www.bilibili.com/video/BV1XXXXX/`), may require cookies for high quality
- **YouTube**: High quality may require authentication
- **Chinese platforms**: May have geo-restrictions; ensure network accessibility

**Quality Access Patterns**:
- Many platforms restrict high quality (1080p+) to authenticated users
- If user requests high quality without authentication:
  - Inform user about platform requirements
  - Offer to use browser cookies (`use_cookies=true`) for authenticated access
  - Suggest highest available quality without authentication as alternative

### Step 4: Check Output Directory

Before downloading:
- **IMPORTANT**: Use current working directory as default output location (not ~/Downloads) to avoid sandbox permission issues
- If user explicitly requests a specific directory, verify it exists, create if it doesn't
- For playlists or series, plan subdirectory structure
- Check if sufficient disk space is available (estimate based on quality and duration)
- If disk space is insufficient, inform user and suggest lower quality or different location
- **Sandbox-Aware**: If download fails with permission error, retry with current working directory

### Step 5: Preview Content Information

Before downloading, fetch and display content metadata:

**Display to User**:
- Media title
- Creator/Channel name
- Duration
- Available quality options
- Subtitle/caption availability
- File size estimate (if available)
- For playlists/series: number of items

**Example**:
```
Title: "Introduction to Machine Learning"
Channel: "AI Education"
Duration: 45:32
Available Quality: 720p, 1080p (login required), 4K (premium required)
Subtitles: English, Chinese, Spanish available
Estimated Size: ~350MB at 1080p

Proceed with download?
```

- Allow user to confirm or adjust quality selection
- **Proceed only after user confirmation**

### Step 6: Determine Download Strategy

Based on content type and requirements:

**Single Video**:
- Standard download with quality selection
- Merge video+audio streams if platform uses separate streams (DASH format)

**Playlist/Series**:
- Use playlist download mode
- Organize output with numbered filenames
- Show progress per item

**Audio Only**:
- Extract audio track only
- Convert to requested format (mp3, m4a, etc.)

**With Subtitles/Captions**:
- Download subtitles in requested language
- Optionally embed subtitles into media file
- For ASS format (animated subtitles), use MKV container

**Authenticated Download**:
- Use browser cookies for high quality or restricted content
- Supported browsers: chrome, firefox, edge, safari, brave
- Cookies are accessed temporarily, not stored or logged

### Step 7: Execute Download

Perform the download with appropriate options:
- Apply quality selection based on user preference
- Apply format conversion if requested
- Download subtitles if requested
- Use browser cookies if needed and available
- Monitor download progress
- For playlists/series, show progress per item
- Handle any errors during download (retry if appropriate)

**Execution Command Pattern**:
```bash
# Direct execution (if yt-dlp is in PATH)
yt-dlp [options] [url]

# Via uv tool (if installed via uv)
uv tool run yt-dlp [options] [url]
```

**Note**: Always check which installation method was used and execute accordingly. If `yt-dlp` command is not found directly, try `uv tool run yt-dlp`.

### Step 8: Verify Download Success

After download completes:
- Verify output file(s) exist and have reasonable sizes
- For playlists/series, verify all items downloaded
- If subtitles downloaded, verify subtitle files are present
- For format conversion, verify output format is correct

### Step 9: Inform User

Present results to user:
- Confirm download completed successfully
- Display:
  - Output file path(s)
  - File size(s)
  - Quality achieved
  - Duration
  - Subtitle information (if downloaded)
- Provide guidance on next steps:
  - "File saved to: [path]"
  - "You can play it with any media player"
  - If subtitles downloaded: "Subtitles saved alongside media"

## Constraints

- **Single Responsibility**: Only handles downloading media from URLs. Does not handle media editing, uploading, or streaming.
- **Idempotent**: If file already exists with same content, inform user and skip (unless user requests overwrite)
- **No Hardcoding**: Use intent-based descriptions; AI should adapt commands to platform and environment
- **Public Content Only**: Does not bypass DRM or download pirated content
- **Compliance First**: Always assess copyright and usage context before downloading
- **Respect Platform Terms**: Follow each platform's terms of service
- **Prerequisite Handling**: If yt-dlp or ffmpeg is missing, inform user which are needed and provide installation guidance. Do not attempt to install automatically. Proceed only after user confirms tools are installed.

## Error Handling

- **yt-dlp not found**: "yt-dlp is not installed. Please install it first using one of these methods:\n- `pip install -U yt-dlp`\n- `uv tool install yt-dlp`\n- `pipx install yt-dlp`\nSee `references/installation-guide.md` for platform-specific instructions."
- **ffmpeg not found**: "ffmpeg is required for format conversion. Please install it first. See `references/installation-guide.md` for platform-specific instructions."
- **Invalid URL**: "The provided URL does not appear to be a valid media URL. Please check and try again."
- **Platform not supported**: "This platform is not supported by yt-dlp. Check the supported sites list at https://github.com/yt-dlp/yt-dlp/blob/master/supportedsites.md"
- **Media unavailable**: "This media is no longer available (deleted, private, or region-restricted)."
- **High quality requires authentication**: "High quality requires account login. Use `use_cookies=true` to authenticate with your browser session."
- **Download failed**: "Download encountered an error. Try updating yt-dlp (`pip install -U yt-dlp` or `uv tool install --upgrade yt-dlp`) or check network connection."
- **Insufficient disk space**: "Not enough disk space. Please free up space or choose a lower quality."
- **Copyright concern**: "This content may be copyrighted. Please confirm you have permission to download it."
- **Subtitle not available**: "Subtitles are not available for this media in the requested language."
- **Format conversion failed**: "Failed to convert to requested format. The source format may not support this conversion."
- **Network timeout**: "Download timed out. Check your internet connection or try again later. If using yt-dlp search, try web search instead as fallback."
- **Sandbox permission denied**: "Download failed due to permission restrictions. Retrying with current working directory instead."
- **Access denied (403)**: "Access denied. Try using browser cookies or check if authentication is required."
- **Cookies extraction failed**: "Failed to extract browser cookies. Ensure you are logged into the platform in your browser."
- **Installation failed**: "Unable to install [tool]. Please try installing it manually: see `references/installation-guide.md`"
- **No URL or query provided**: "Please provide either a media URL or search keywords to find the media you want to download."

## Example Usage

**Example 1: Basic Video Download**
```
User: "Download this video: https://youtube.com/watch?v=abc123"
AI: Uses tool-dl-media with url="https://youtube.com/watch?v=abc123"
Result: Downloads video in best available quality
```

**Example 2: Audio Extraction**
```
User: "I need the audio from this podcast"
AI: Uses tool-dl-media with url="...", quality="audio-only"
Result: Extracts and saves audio file
```

**Example 3: Download with Subtitles**
```
User: "Download this tutorial with Chinese subtitles"
AI: Uses tool-dl-media with url="...", subtitles=true, subtitle_lang="zh"
Result: Downloads video with Chinese subtitles
```

**Example 4: Specific Quality**
```
User: "Download this video in 720p to save space"
AI: Uses tool-dl-media with url="...", quality="720p"
Result: Downloads in 720p resolution
```

**Example 5: High Quality with Authentication**
```
User: "Download this in 1080p"
AI: "1080p requires login. I'll use your browser cookies to authenticate."
AI: Uses tool-dl-media with url="...", quality="1080p", use_cookies=true
Result: Downloads 1080p video using browser authentication
```

**Example 6: Playlist Download**
```
User: "Download all videos from this playlist for offline study"
AI: Uses tool-dl-media with playlist URL
Result: Downloads entire playlist with organized filenames
```

**Example 7: Format Conversion**
```
User: "Download this as MP3"
AI: Uses tool-dl-media with url="...", quality="audio-only", output_format="mp3"
Result: Downloads and converts to MP3
```

**Example 8: Compliance Check Triggered**
```
User: "Download this movie for our company event"
AI: Assesses context, detects commercial use and copyrighted content
Result: "This content is copyrighted. For commercial use, please ensure you have proper licensing. Do you want to proceed for personal review only?"
```

**Example 9: Keyword-Based Download (No URL)**
```
User: "Download the song 洗牌 by SHarK"
AI: Searches for "洗牌 SHarK" on Bilibili and YouTube
AI: Presents results to user for selection
User: "The first one"
AI: Uses tool-dl-media with url="https://www.bilibili.com/video/BV1XXXXX/", quality="audio-only", output_format="mp3"
Result: Downloads audio file
```

**Example 10: Chinese Platform (Bilibili) Download**
```
User: "Download this B站 video: https://www.bilibili.com/video/BV1XXXXX/"
AI: Uses tool-dl-media with url="https://www.bilibili.com/video/BV1XXXXX/"
Note: For Bilibili, yt-dlp supports both BV号 and AV号 formats
Result: Downloads video in best available quality
```

## Implementation Notes

**Core Tool**: `yt-dlp` (https://github.com/yt-dlp/yt-dlp)

**Installation Methods Detection**:
- First try: `yt-dlp --version` (direct PATH)
- Fallback: `uv tool run yt-dlp --version` (uv tool)
- Fallback: `pipx run yt-dlp --version` (pipx)

**URL Discovery Best Practices**:
- **DO NOT** use yt-dlp's built-in search (`ytsearch:`) - it frequently times out
- **DO** use web search (WebSearch tool) to find media URLs
- Present results in a table format with No., Platform, Title, Duration, URL columns
- Let user select by number or provide their own URL

**Sandbox/Permission Handling**:
- Always use current working directory as default output location
- Avoid hardcoding paths like ~/Downloads which may trigger sandbox restrictions
- If permission denied error occurs, retry with current directory
- For Windows sandbox environments, prefer relative paths

**Key Capabilities**:
- Supports 1000+ websites
- Automatic format selection and merging
- Subtitle/caption download and embedding
- Metadata preservation
- Batch/playlist downloads
- Browser cookie integration

**Platform-Specific Guidance**:

**Bilibili (B站)**:
- URL formats: `https://www.bilibili.com/video/BVxxxxx/` or `https://www.bilibili.com/video/avxxxxx/`
- yt-dlp fully supports Bilibili
- For high quality or restricted content, may need cookies
- Chinese content may require network accessibility from mainland China
- Search fallback: Use web search with `site:bilibili.com {keywords}` if user only provides keywords

**YouTube**:
- High quality (1080p+) may require authentication
- Supports playlists and channels
- Search fallback: Use `ytsearch{N}:{keywords}` syntax or web search

**Quality Selection Guide**:
- `best`: Highest available quality (may require authentication)
- `4k`: Ultra HD (may require premium subscription)
- `1080p`: Full HD (may require login on many platforms)
- `720p`: HD (typically available without login)
- `480p`: Standard definition
- `360p`: Low quality (for preview/mobile)
- `audio-only`: Extract audio only

**Browser Cookie Authentication**:
- Required for high quality on many platforms
- Command: `--cookies-from-browser chrome` (or firefox, edge, safari, brave)
- Security: Cookies are accessed temporarily, not stored or logged
- User must be logged into the platform in the specified browser

**Subtitle/Caption Formats**:
- SRT: Most widely supported
- VTT: Web standard
- ASS: Advanced SubStation Alpha (animated subtitles)
- For embedding ASS subtitles, use MKV container (MP4 doesn't support ASS)

**File Naming**:
- Use output template to organize files:
  - `%(title)s [%(id)s].%(ext)s` for single media
  - `%(playlist)s/%(playlist_index)02d - %(title)s.%(ext)s` for playlists

**Security Notes**:
- Never store or log credentials
- Browser cookies are accessed temporarily and not persisted
- Validate all URLs before processing
- Be cautious with user-provided output paths (prevent path traversal)
