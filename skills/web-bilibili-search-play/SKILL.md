---
name: web-bilibili-search-play
description: Use this skill when the user wants to search for content on Bilibili, find specific videos, or play videos from Bilibili search results. Supports keyword search and automatic playback of top results.
metadata:
  version: 1.0.0
  displayName: Search and Play Bilibili Video
  domain: web
  action: search
  object: bilibili-video
  tags: [web, bilibili, search, video, browser]
  type: SKILL
inputs:
  - name: search_query
    type: string
    required: true
    description: Search query string (e.g., "AI tutorial", "Python programming")
  - name: video_index
    type: integer
    required: false
    description: Which video to play from search results (default: 1, i.e., first video)
  - name: headed_mode
    type: boolean
    required: false
    description: Whether to run browser in headed mode (visible, default: true)
---
# Search and Play Bilibili Video

## Purpose

Search for videos on Bilibili and automatically play the top result only. Does not handle video analysis, comments, or user interactions.

## Trigger Conditions

Use this Skill when:
- User wants to search for specific content on Bilibili
- User wants to find and play videos by keyword
- User needs to quickly access relevant video content
- User wants to browse Bilibili for a specific topic

## Prerequisites

- Internet connection is available
- Bilibili.com is accessible from the network
- Browser automation capability is available (browser-use recommended)
- Python environment with browser-use library installed

## Execution Steps

### Step 1: Validate Input Parameters

Before executing:
- Verify `search_query` parameter is provided and not empty
- If `video_index` is provided, ensure it's a positive number (1-10)
- If `video_index` is not provided, default to 1 (first video)
- If `headed_mode` is not provided, default to true (visible browser)
- If validation fails, inform user with specific error message

### Step 2: Initialize Browser Automation

Set up browser-use with appropriate configuration:
- Use headed mode if `headed_mode` is true (shows browser window)
- Use headless mode if `headed_mode` is false (background execution)
- Ensure browser is properly initialized
- Verify browser automation is ready

### Step 3: Navigate to Bilibili Homepage

Using browser automation:
- Open Bilibili homepage (https://www.bilibili.com)
- Wait for page to load completely
- Verify homepage is accessible and shows main content
- Handle any popups or cookie consent dialogs if they appear

### Step 4: Locate and Fill Search Input

On Bilibili homepage:
- Find the search input field (typically at top center of page)
- Clear any existing text in search box
- Enter the provided `search_query` parameter
- Ensure text is fully entered and visible

### Step 5: Submit Search and Wait for Results

- Click the search button or press Enter to submit search
- Wait for search results page to load
- Ensure search results are fully rendered
- Verify search query matches what was entered

### Step 6: Extract Search Results

From the search results page:
- Locate video list/grid container
- Identify individual video cards/thumbnails
- For each video result (up to 10):
  - Extract video title
  - Extract video URL
  - Extract video thumbnail
  - Extract video duration
  - Extract view count
  - Extract uploader name
- Store results as structured data

### Step 7: Validate Video Availability

Before playing:
- Check if search results contain any videos
- If no results found, inform user and stop
- If `video_index` exceeds available results, inform user and use last available video
- Verify the selected video is accessible (not region-locked or deleted)

### Step 8: Click and Play Selected Video

- Locate the video at position `video_index` in search results
- Click on the video card/thumbnail to open video page
- Wait for video player page to load
- Verify video player is initialized
- If video doesn't auto-play, click the play button
- Ensure video is playing (not paused)

### Step 9: Verify Playback Status

After clicking video:
- Confirm video is playing (check play state)
- Verify video title matches selected video
- Ensure no error messages (e.g., "video unavailable")
- Wait a few seconds to confirm stable playback

### Step 10: Keep Browser Open for User

After successful playback:
- **Do not close browser** - Leave it open for user to watch
- **Keep video playing** - Allow user to continue watching
- Inform user that browser is ready for viewing
- Provide video information (title, URL, duration)

### Step 11: Inform User

Present results to user:
- Confirm video is playing successfully
- Display video information:
  - Video title
  - Video URL
  - Uploader name
  - Video duration
  - Search query used
- Mention that browser is in headed mode (visible)
- Offer to play other videos from search results if needed

## Constraints

- **Single Responsibility**: Only handles Bilibili search and video playback, not content analysis or comments
- **Idempotent**: Each search is independent, no session persistence
- **Tool Agnostic**: AI chooses appropriate browser automation tools based on availability
- **Respect Terms**: Follow Bilibili's terms of service, avoid excessive automated requests
- **Public Content Only**: Only accesses publicly available videos
- **No Login Required**: Does not handle user authentication or logged-in features
- **Headed Mode Default**: Uses visible browser by default for better user experience
- **User Experience Focus**: Keep browser open for user to watch, don't close automatically

## Error Handling

- **No automation tool available**: Inform user no browser automation tool found, provide manual Bilibili search URL
- **Network error**: Inform user to check internet connection and firewall settings
- **Bilibili homepage load timeout**: Inform user Bilibili may be unavailable or blocked
- **Search query empty**: Inform user to provide search query
- **No search results found**: Inform user no videos found for this query, suggest different keywords
- **Video index out of range**: Inform user requested video index exceeds results, show available count
- **Video unavailable**: Inform user selected video is unavailable (deleted, region-locked, or private)
- **Video playback failed**: Inform user video failed to play, page may have loading issues
- **Browser automation failed**: Inform user browser automation encountered error, try alternative approach
- **Access blocked**: Inform user access to Bilibili is blocked or restricted from network
- **Headed mode not supported**: If headed mode fails (e.g., no display), inform user and suggest headless mode

## Example Usage

**Example 1: Basic Search and Play**
```
User: "Search for AI tutorial on Bilibili and play the first video"
AI: Uses web-bilibili-search-play with search_query="AI tutorial"
Result: Opens browser, searches for "AI tutorial", plays first video
```

**Example 2: Custom Video Index**
```
User: "Find Python programming videos on Bilibili, play the third one"
AI: Uses web-bilibili-search-play with search_query="Python programming", video_index=3
Result: Opens browser, searches, plays the 3rd video from results
```

**Example 3: Headless Mode (Background)**
```
User: "Search for machine learning videos in background"
AI: Uses web-bilibili-search-play with search_query="machine learning", headed_mode=false
Result: Runs browser in headless mode, searches and plays video without showing UI
```

**Example 4: Specific Topic Search**
```
User: "I want to watch videos about deep learning"
AI: Uses web-bilibili-search-play with search_query="deep learning tutorial"
Result: Opens browser in headed mode, searches and plays top result
```

**Example 5: Fallback When Automation Unavailable**
```
User: "Play AI videos on Bilibili"
AI: Browser automation not available, provides manual search URL
Result: User can click link to search manually on Bilibili
```

## Implementation Notes

**Workflow**:
1. Initialize browser-use with headed mode (visible browser)
2. Navigate to Bilibili homepage
3. Enter search query and submit
4. Extract search results (titles, URLs, metadata)
5. Click on selected video (by index)
6. Wait for video to load and start playing
7. Keep browser open for user to watch
8. Provide video information to user

**Key Points**:
- Use headed mode by default (better user experience)
- Focus on user experience (show browser, don't close automatically)
- Extract meaningful information (not just URLs)
- Handle errors gracefully
- Respect Bilibili's terms of service
- Default to playing first video if index not specified

**Recommended Tool**:
- Primary: `browser-use` (if available in environment)
- Fallback: Any browser automation tool (Playwright, Puppeteer, Selenium)

**Why browser-use?**
- Natural language understanding
- Intelligent element location
- Better error handling
- Works well with complex web applications like Bilibili
