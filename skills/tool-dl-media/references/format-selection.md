# Format Selection Guide

## Understanding Media Formats

### Common Video Containers
- **MP4**: Most compatible, widely supported across devices and platforms
- **MKV**: Supports multiple audio/subtitle tracks, ASS subtitles, ideal for archival
- **WebM**: Modern web format, VP9/AV1 codecs, smaller file sizes
- **FLV**: Legacy format, limited modern use

### Common Video Codecs
- **H.264/AVC**: Most compatible, good compression
- **H.265/HEVC**: Better compression than H.264, widely supported
- **VP9**: Open source, used by YouTube, good compression
- **AV1**: Next-gen open codec, best compression but slower encoding

### Common Audio Codecs
- **AAC**: Standard for MP4 containers, good quality
- **MP3**: Most compatible, universal support
- **Opus**: Best quality for speech/podcasts, modern standard
- **Vorbis**: Open source, used in WebM/OGG
- **FLAC**: Lossless audio, large file sizes

## Quality vs Size Tradeoffs

### Video Quality
| Quality | Typical Bitrate | File Size (per hour) | Use Case |
|---------|-----------------|---------------------|----------|
| 4K | 15-25 Mbps | 7-11 GB | Archival, professional editing |
| 1080p | 5-8 Mbps | 2-4 GB | General viewing, training materials |
| 720p | 2.5-4 Mbps | 1-2 GB | Storage conscious, mobile devices |
| 480p | 1-2 Mbps | 0.5-1 GB | Low bandwidth, preview |
| 360p | 0.5-1 Mbps | 0.2-0.5 GB | Quick reference only |

### Audio Quality
| Format | Recommended Bitrate | File Size (per hour) | Use Case |
|--------|---------------------|---------------------|----------|
| MP3 | 128 kbps | 60 MB | Podcasts, speech |
| MP3 | 192-256 kbps | 90-120 MB | Music, general use |
| M4A/AAC | 128 kbps | 55 MB | Podcasts, better quality than MP3 |
| M4A/AAC | 192 kbps | 85 MB | Music |
| Opus | 96 kbps | 45 MB | Podcasts/speech (best quality/size) |
| Opus | 128 kbps | 60 MB | Music (transparent quality) |
| FLAC | Lossless | 300-500 MB | Archival, audiophile |

## yt-dlp Format Selection Examples

### Download Best Quality
```bash
yt-dlp -f "bestvideo+bestaudio/best" URL
```

### Specific Quality
```bash
yt-dlp -f "bestvideo[height=1080]+bestaudio/best[height=1080]" URL
```

### Audio Only
```bash
yt-dlp -x --audio-format mp3 --audio-quality 192K URL
```

### Video with Specific Codec
```bash
yt-dlp -f "bestvideo[vcodec^=av01]+bestaudio/best" URL
```

## Recommendations by Use Case

| Scenario | Recommended Format | Notes |
|----------|-------------------|-------|
| Offline training | MP4, 1080p | Good balance of quality and compatibility |
| Podcast archive | M4A/AAC 128kbps | Smaller than MP3, better quality |
| Research archive | MKV, best quality | Preserves all streams, multiple subtitles |
| Mobile viewing | MP4, 720p | Good for smaller screens |
| Music collection | FLAC or Opus 128kbps | Lossless or transparent quality |
| Quick reference | MP4, 480p | Small file size for quick access |
