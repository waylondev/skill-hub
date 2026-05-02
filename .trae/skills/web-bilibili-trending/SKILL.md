---
name: web-bilibili-trending
description: Use this skill when the user wants to browse trending videos on Bilibili, discover popular content by category, or analyze trending video data. Returns structured trending video information.
metadata:
  version: 1.0.0
  displayName: Bilibili Trending Videos
  domain: web
  action: browse
  object: bilibili-trending
  tags: [web, bilibili, trending, videos]
  type: SKILL
inputs:
  - name: category
    type: string
    required: false
    description: Bilibili category to filter trending videos (default: all categories)
  - name: time_range
    type: string
    required: false
    description: Time range for trending videos (today, this_week, this_month)
  - name: open_browser
    type: boolean
    required: false
    description: Whether to open browser with trending page (default: true)
---
# Bilibili Trending Videos

## Purpose

Browse Bilibili trending videos and show popular content only. Does not handle video playback or detailed content analysis.

## Trigger Conditions

Use this Skill when:
- User wants to see what's popular on Bilibili
- User needs to browse trending videos by category
- User wants to discover new content on Bilibili
- Research or content analysis is required

## Prerequisites

- Internet connection is available
- Bilibili.com is accessible from the network
- Browser automation capability is available (AI will use appropriate tools)

## Execution Steps

### Step 1: Validate Input Parameters

Before executing:
- Verify `category` parameter if provided (check against valid Bilibili categories)
- If `time_range` is provided, ensure it's one of: 'today', '3days', 'week'
- If `time_range` is not provided, default to 'today'
- If `num_results` is provided, ensure it's between 1-50
- If `num_results` is not provided, default to 10
- If validation fails, inform user with specific error message

### Step 2: Choose Approach

Select the best approach based on environment and user needs:
- **Interactive** (user wants to watch) → Use browser automation
- **Data-only** (user wants info) → Use API or HTTP client
- **Fallback** → Provide manual links

### Step 3: Navigate to Bilibili Trending Page

Using the chosen tool:
- Open Bilibili homepage
- Navigate to the trending/ranking page
- Wait for page to load completely
- Verify page is accessible and shows trending content

### Step 4: Apply Filters (If Specified)

If `category` parameter is provided:
- Locate category filter on the page
- Select the specified category
- Wait for page to refresh with filtered results

If `time_range` parameter is provided:
- Locate time range filter (today/3days/week)
- Select the specified time range
- Wait for page to update with filtered results

### Step 5: Extract Trending Videos

From the trending page:
- Locate video list container
- For each video (up to `num_results`):
  - Extract video title
  - Extract video URL
  - Extract thumbnail URL
  - Extract view count
  - Extract like count (danmaku/likes)
  - Extract uploader/channel name
  - Extract video duration
  - Extract ranking position
  - Store as structured data
- Handle special cases:
  - Sponsored/promoted videos
  - New uploads vs established trending
  - Different video formats (vertical, horizontal)

### Step 6: Format and Return Results

Organize trending videos:
- Create a readable summary with:
  - Category (if filtered)
  - Time range
  - Number of videos returned
  - List of videos with title, URL, views, uploader
- Format in a clear, readable structure
- Include the trending page URL for reference
- Optionally include thumbnail images if supported

### Step 7: Open Video in Browser (If User Selects)

If user selects a specific video to watch:
- **Extract the video URL** from the trending list
- **Open the video in user's browser**
- **Keep browser open** for user to watch the video
- **Verify page loads successfully**

### Step 8: Clean Up

After completing the task:
- **Do not close browser** - Leave it open for user to watch video
- Clean up any temporary resources (if any were created)
- Ensure no background processes left running

### Step 9: Inform User

Present results to user:
- Display formatted trending videos list
- Provide summary statistics (total views, top category, etc.)
- **Confirm if browser was opened successfully**
- Mention if any errors or limitations encountered
- Suggest related categories if user wants to explore more

## Constraints

- **Single Responsibility**: Only handles Bilibili trending videos (not search or other pages)
- **Read-Only**: No login, comments, or interactions beyond viewing
- **Tool Agnostic**: AI chooses appropriate tools based on availability
- **Respect Terms**: Follow Bilibili's terms of service, avoid excessive requests
- **Public Content Only**: Only accesses publicly available videos
- **No Session Persistence**: Each request is independent

## Error Handling

- **No automation tool available**: Inform user no web automation tool found, offer manual browsing guidance
- **Network error**: Inform user to check internet connection and firewall settings
- **Page load timeout**: Inform user page failed to load, website may be unavailable
- **Invalid category**: Inform user category is not valid
- **No trending videos found**: Inform user no trending videos found, page structure may have changed
- **Results extraction failed**: Inform user failed to extract results, page structure may have changed
- **Access blocked**: Inform user access is blocked or restricted from network
- **Tool execution failed**: Inform user automation tool encountered error, try alternative approach
- **Region restriction**: Inform user content may not be available in region
- **Browser open failed**: Inform user unable to open browser automatically, provide link for manual opening
- **System command not available**: Inform user system command not available on platform

## Example Usage

**Example 1: Basic Trending**
```
User: "Show me what's trending on Bilibili"
AI: Uses web-bilibili-trending with default parameters
Result: Returns top 10 trending videos for today
```

**Example 2: Category Filter**
```
User: "What's popular in the animation category on Bilibili?"
AI: Uses web-bilibili-trending with category="animation"
Result: Returns top 10 trending animation videos
```

**Example 3: Custom Time Range**
```
User: "Show me this week's trending videos on Bilibili, top 20"
AI: Uses web-bilibili-trending with time_range="week", num_results=20
Result: Returns top 20 trending videos for the week
```

**Example 4: Content Discovery**
```
User: "I want to discover new content on Bilibili"
AI: Uses web-bilibili-trending to show trending videos
Result: Returns diverse trending content across categories
```

**Example 5: Open Specific Video**
```
User: "Show me trending videos, I want to watch the first one"
AI: Uses web-bilibili-trending to get trending list, then opens browser
Result: Opens the #1 trending video URL in user's default browser
```

**Example 6: Interactive Browsing**
```
User: "What's trending on Bilibili?"
AI: Shows trending list with numbered videos
User: "Open video 3"
AI: Opens the 3rd video URL in browser automatically
Result: Browser launches and plays the selected video
```

**Example 7: Fallback When Automation Unavailable**
```
User: "Show me Bilibili trending"
AI: Browser automation not available, provides manual links
Result: User can click links to browse manually
```

## Implementation Notes

**Workflow**:
1. Navigate to Bilibili trending page
2. Extract video information (title, URL, views, uploader)
3. Present results to user in a clear format
4. If user selects a video, open it in their browser
5. Keep browser open for user to watch

**Key Points**:
- Focus on user experience (show browser, don't close automatically)
- Extract meaningful information (not just URLs)
- Handle errors gracefully
- Respect website terms of service
