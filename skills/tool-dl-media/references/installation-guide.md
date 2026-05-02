# Prerequisite Installation Guide

## Overview

This skill requires `yt-dlp` and `ffmpeg` to be installed and available in PATH. This guide provides installation instructions for all major platforms.

## Check Installation

```bash
yt-dlp --version
ffmpeg -version
```

If either command is not found or returns an error, follow the installation steps below.

---

## yt-dlp Installation

### Method 1: Via pip (Recommended, Cross-Platform)
```bash
pip install -U yt-dlp
```
- Works on Windows, macOS, Linux
- Requires Python 3.8+

### Method 2: Via pipx (Isolated Environment)
```bash
pipx install yt-dlp
```
- Keeps yt-dlp in isolated virtual environment
- Recommended for Python tool management

### Method 3: Via Package Manager

**macOS (Homebrew)**:
```bash
brew install yt-dlp
```

**Windows (winget)**:
```bash
winget install yt-dlp
```

**Linux (apt, Debian/Ubuntu)**:
```bash
sudo apt update && sudo apt install -y python3-pip && pip3 install yt-dlp
```

**Linux (dnf, Fedora/RHEL)**:
```bash
sudo dnf install -y python3-pip && pip3 install yt-dlp
```

### Method 4: Direct Download
- Download from [GitHub Releases](https://github.com/yt-dlp/yt-dlp/releases)
- Place the executable in a directory in your PATH
- No dependencies required (standalone executable)

---

## ffmpeg Installation

### Method 1: Via Package Manager (Recommended)

**macOS (Homebrew)**:
```bash
brew install ffmpeg
```

**Linux (apt, Debian/Ubuntu)**:
```bash
sudo apt update && sudo apt install ffmpeg
```

**Linux (dnf, Fedora/RHEL)**:
```bash
sudo dnf install ffmpeg
```

**Linux (pacman, Arch)**:
```bash
sudo pacman -S ffmpeg
```

**Windows (winget)**:
```bash
winget install ffmpeg
```

**Windows (Chocolatey)**:
```bash
choco install ffmpeg
```

### Method 2: Direct Download

**Windows**:
- Download from [gyan.dev](https://www.gyan.dev/ffmpeg/builds/)
- Extract the archive
- Add the `bin/` directory to your system PATH

**macOS/Linux**:
- Download static builds from [ffmpeg.org](https://ffmpeg.org/download.html)
- Place in `/usr/local/bin` or add to PATH

### Verify Installation
```bash
ffmpeg -version
```
Should show version information and enabled features.

---

## Installation Workflow

1. **Check**: Verify if yt-dlp and ffmpeg are available
2. **Install**: Run the appropriate installation command for the user's platform
3. **Verify**: After installation, re-check that tools are accessible
4. **Proceed**: Continue with download only when all prerequisites are satisfied

### Troubleshooting

| Issue | Solution |
|-------|----------|
| `pip: command not found` | Install Python first, or use package manager method |
| `brew: command not found` | Install Homebrew: `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"` |
| `winget: command not found` | Update Windows to version 1709+ or use Chocolatey |
| Permission denied | Use `sudo` (Linux/macOS) or run as Administrator (Windows) |
| `yt-dlp` not found after pip install | Add Python Scripts directory to PATH |
| `ffmpeg` not found after download | Ensure `bin/` directory is added to PATH, then restart terminal |
